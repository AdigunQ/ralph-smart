package core

import (
    "context"
    "math/big"
    "testing"

    "github.com/ethereum/go-ethereum/common"
    "github.com/ethereum/go-ethereum/core/blockstm"
    "github.com/ethereum/go-ethereum/core/rawdb"
    "github.com/ethereum/go-ethereum/core/state"
    "github.com/ethereum/go-ethereum/core/types"
    "github.com/ethereum/go-ethereum/core/vm"
    "github.com/ethereum/go-ethereum/params"
    "github.com/ethereum/go-ethereum/trie"
    "github.com/ethereum/go-ethereum/triedb"
)

// FuzzLabBorMainnetV2Parity runs the existing real-transaction grammar under
// Bor's live mainnet rules instead of MergedTestChainConfig. It intentionally
// rejects every SELFDESTRUCT/destruction-lifecycle kind so PR #2403 and the
// older public destruction findings cannot be rediscovered in this lane.
func FuzzLabBorMainnetV2Parity(f *testing.F) {
    seeds := [][]byte{
        {byte(kindTransferToSender), 0, 1, 1, 0, byte(kindTransferToFresh), 1, 0xaa, 2, 0},
        {byte(kindContractCreate), 0, 0, 0, 0, byte(kindContractCall), 1, 0, 0, 0},
        {byte(kind7702Auth), 0, 0x80, 0, 0, byte(kind7702Auth), 1, 0, 0, 0},
        {byte(kindTransient), 0, 0, 0, 0, byte(kindClearRefund), 1, 0, 0, 0, byte(kindEmitLog), 2, 0, 0, 0},
        {byte(kindCreate2Deploy), 0, 0, 0, 0, byte(kindReadTarget), 1, 0, 0, 0, byte(kindDelegateRead), 2, 0, 0, 0},
    }
    for _, seed := range seeds { f.Add(seed) }
    f.Fuzz(func(t *testing.T, data []byte) {
        decoded := decodeScenario(data)
        if len(decoded) == 0 || labHasKnownDestructionKind(decoded) { return }
        labRunBorScenarioAndAssertParity(t, decoded, 8)
    })
}

func labHasKnownDestructionKind(decoded []fuzzTx) bool {
    for _, tx := range decoded {
        switch tx.kind {
        case kindCallSelfDestructPair, kindCreate2AndDestroy, kindDestroyTarget:
            return true
        }
    }
    return false
}

func labRunBorScenarioAndAssertParity(t testing.TB, decoded []fuzzTx, workers int) {
    t.Helper()
    config := params.BorMainnetChainConfig
    tdb, root := buildBaseStateRoot(t)
    blockNumber := new(big.Int).SetUint64(91_949_701)
    blockTime := uint64(1_790_000_000)
    baseFee := big.NewInt(1)
    blockCtx := vm.BlockContext{
        CanTransfer: CanTransfer,
        Transfer: Transfer,
        GetHash: func(uint64) common.Hash { return common.Hash{} },
        Coinbase: fuzzCoinbase,
        GasLimit: 30_000_000,
        BlockNumber: blockNumber,
        Time: blockTime,
        BaseFee: baseFee,
        Random: &common.Hash{},
    }
    signer := types.MakeSigner(config, blockNumber, blockTime)
    txs, msgs := signedTxs(t, decoded, signer, baseFee)
    if len(txs) == 0 { return }

    sRoot, sReceipts := labRunSerialWithConfig(t, tdb, root, txs, msgs, blockCtx, config)
    vRoot, vReceipts := labRunV2WithConfig(t, tdb, root, txs, msgs, blockCtx, config, workers)
    if sRoot != vRoot {
        t.Fatalf("BOR STATE ROOT DIVERGENCE serial=%s v2=%s workers=%d decoded=%v", sRoot, vRoot, workers, decoded)
    }
    if len(sReceipts) != len(vReceipts) {
        t.Fatalf("BOR RECEIPT COUNT DIVERGENCE serial=%d v2=%d decoded=%v", len(sReceipts), len(vReceipts), decoded)
    }
    for i := range sReceipts {
        s, v := sReceipts[i], vReceipts[i]
        if s.Status != v.Status || s.GasUsed != v.GasUsed || s.CumulativeGasUsed != v.CumulativeGasUsed || s.Bloom != v.Bloom || len(s.Logs) != len(v.Logs) {
            t.Fatalf("BOR RECEIPT FIELD DIVERGENCE tx=%d serial=%+v v2=%+v decoded=%v", i, s, v, decoded)
        }
        for j := range s.Logs {
            sl, vl := s.Logs[j], v.Logs[j]
            if sl.Address != vl.Address || len(sl.Topics) != len(vl.Topics) || string(sl.Data) != string(vl.Data) {
                t.Fatalf("BOR LOG DIVERGENCE tx=%d log=%d serial=%+v v2=%+v decoded=%v", i, j, sl, vl, decoded)
            }
            for k := range sl.Topics {
                if sl.Topics[k] != vl.Topics[k] {
                    t.Fatalf("BOR LOG TOPIC DIVERGENCE tx=%d log=%d topic=%d decoded=%v", i, j, k, decoded)
                }
            }
        }
    }
    sr := types.DeriveSha(sReceipts, trie.NewStackTrie(nil))
    vr := types.DeriveSha(vReceipts, trie.NewStackTrie(nil))
    if sr != vr { t.Fatalf("BOR RECEIPT ROOT DIVERGENCE serial=%s v2=%s decoded=%v", sr, vr, decoded) }
}

func labRunSerialWithConfig(t testing.TB, tdb *triedb.Database, root common.Hash, txs []*types.Transaction, msgs []*Message, blockCtx vm.BlockContext, config *params.ChainConfig) (common.Hash, types.Receipts) {
    t.Helper()
    sdb, err := state.New(root, state.NewDatabase(tdb, nil))
    if err != nil { t.Fatal(err) }
    gp := new(GasPool).AddGas(blockCtx.GasLimit)
    var used uint64
    receipts := make(types.Receipts, 0, len(txs))
    for i, tx := range txs {
        sdb.SetTxContext(tx.Hash(), i)
        evm := vm.NewEVM(blockCtx, sdb, config, vm.Config{})
        receipt, err := ApplyTransactionWithEVM(msgs[i], gp, sdb, blockCtx.BlockNumber, common.Hash{}, blockCtx.Time, tx, &used, evm)
        if err != nil { t.Fatalf("serial tx %d: %v", i, err) }
        receipts = append(receipts, receipt)
    }
    return sdb.IntermediateRoot(true), receipts
}

func labRunV2WithConfig(t testing.TB, tdb *triedb.Database, root common.Hash, txs []*types.Transaction, msgs []*Message, blockCtx vm.BlockContext, config *params.ChainConfig, workers int) (common.Hash, types.Receipts) {
    t.Helper()
    base, err := state.New(root, state.NewDatabase(tdb, nil))
    if err != nil { t.Fatal(err) }
    finalDB, err := state.New(root, state.NewDatabase(tdb, nil))
    if err != nil { t.Fatal(err) }
    tasks := make([]V2Task, len(txs))
    for i := range txs { tasks[i] = V2Task{Index: i, Tx: txs[i], Msg: msgs[i]} }
    res := ExecuteV2BlockSTM(context.Background(), tasks, base, blockstm.NewMVStore(), blockstm.NewMVBalanceStore(), blockCtx, common.Hash{}, vm.Config{}, config, blockCtx.GasLimit, workers, finalDB, nil)
    if res.PanickedIdx >= 0 { t.Fatalf("V2 tx %d panicked", res.PanickedIdx) }
    if res.ExecErrIdx >= 0 { t.Fatalf("V2 tx %d consensus error: %v", res.ExecErrIdx, res.ExecErr) }
    if res.ReadErr != nil { t.Fatalf("V2 read error: %v", res.ReadErr) }
    return finalDB.IntermediateRoot(true), res.Receipts
}

var _ = rawdb.NewMemoryDatabase
