package eth

import (
    "bytes"
    "math/big"
    "runtime"
    "sync/atomic"
    "testing"
    "time"

    "github.com/ethereum/go-ethereum/core/types"
    "github.com/ethereum/go-ethereum/p2p"
    "github.com/ethereum/go-ethereum/rlp"
)

type labPacketBackend struct {
    *testBackend
    delivered chan int
}

func (b *labPacketBackend) Handle(_ *Peer, packet Packet) error {
    if txs, ok := packet.(*TransactionsPacket); ok {
        b.delivered <- len(*txs)
    }
    return nil
}

func TestLabTransactionsWireControl(t *testing.T) {
    labRunTransactionsWireCase(t, 64*1024)
}

func TestLabTransactionsWireNearLimit(t *testing.T) {
    labRunTransactionsWireCase(t, maxMessageSize-64*1024)
}

func labRunTransactionsWireCase(t *testing.T, target int) {
    payload, count := labBuildTinyTransactionsPacket(t, target)
    if len(payload) > maxMessageSize {
        t.Fatalf("payload exceeds protocol cap: %d > %d", len(payload), maxMessageSize)
    }
    t.Logf("PAYLOAD bytes=%d txs=%d target=%d", len(payload), count, target)

    base := newTestBackend(0)
    backend := &labPacketBackend{testBackend: base, delivered: make(chan int, 1)}
    defer base.close()
    peer, errc := newTestPeer("wire-pressure", ETH69, backend)
    defer peer.close()

    runtime.GC()
    var before runtime.MemStats
    runtime.ReadMemStats(&before)
    var peakAlloc atomic.Uint64
    peakAlloc.Store(before.Alloc)
    stop := make(chan struct{})
    donePoll := make(chan struct{})
    go func() {
        ticker := time.NewTicker(time.Millisecond)
        defer ticker.Stop()
        defer close(donePoll)
        for {
            select {
            case <-ticker.C:
                var m runtime.MemStats
                runtime.ReadMemStats(&m)
                for {
                    old := peakAlloc.Load()
                    if m.Alloc <= old || peakAlloc.CompareAndSwap(old, m.Alloc) { break }
                }
            case <-stop:
                return
            }
        }
    }()

    started := time.Now()
    err := peer.app.WriteMsg(p2p.Msg{Code: TransactionsMsg, Size: uint32(len(payload)), Payload: bytes.NewReader(payload)})
    if err != nil { t.Fatalf("wire write: %v", err) }
    select {
    case got := <-backend.delivered:
        if got != count { t.Fatalf("decoded count=%d want=%d", got, count) }
    case err := <-errc:
        t.Fatalf("protocol exited before delivery: %v", err)
    case <-time.After(3 * time.Minute):
        t.Fatal("handler did not complete within 3 minutes")
    }
    elapsed := time.Since(started)
    close(stop)
    <-donePoll
    var after runtime.MemStats
    runtime.ReadMemStats(&after)
    t.Logf("RESULT elapsed=%s alloc_before=%d peak_alloc=%d alloc_after=%d total_alloc_delta=%d num_gc_delta=%d",
        elapsed, before.Alloc, peakAlloc.Load(), after.Alloc, after.TotalAlloc-before.TotalAlloc, after.NumGC-before.NumGC)
}

func labBuildTinyTransactionsPacket(t testing.TB, target int) ([]byte, int) {
    t.Helper()
    zero := new(big.Int)
    raws := make([]rlp.RawValue, 0, target/18)
    body := 0
    for i := uint64(0); ; i++ {
        tx := types.NewTx(&types.LegacyTx{
            Nonce: i,
            GasPrice: zero,
            Gas: 21_000,
            To: nil,
            Value: zero,
            Data: nil,
            V: zero,
            R: zero,
            S: zero,
        })
        enc, err := rlp.EncodeToBytes(tx)
        if err != nil { t.Fatal(err) }
        nextBody := body + len(enc)
        if int(rlp.ListSize(uint64(nextBody))) > target {
            break
        }
        raws = append(raws, rlp.RawValue(enc))
        body = nextBody
    }
    payload, err := rlp.EncodeToBytes(raws)
    if err != nil { t.Fatal(err) }
    if len(payload) > target { t.Fatalf("builder overshot: %d > %d", len(payload), target) }
    return payload, len(raws)
}
