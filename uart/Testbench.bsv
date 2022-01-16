package Testbench;

import StmtFSM :: *;
import Clocks :: *;
import GetPut :: *;

import Defs :: *;
import UART :: *;
import UART_TX :: *;
import UART_RX :: *;

module mkTestbench();
    Clock _currClk <- exposeCurrentClock();

    //clock for simulation
    Clock clk <- mkAbsoluteClockFull(1, 1'b1, 1, 1);
    //synchronized reset for simulated module, so we can reset it from the testbench
    Reset rst <- mkInitialReset(2, clocked_by clk);
    Reset rstRX <- mkInitialReset(4, clocked_by clk); //rx has to wait until output of tx is stable

    Integer clockDivisor = 8;

    // ------------------- TX ----------------------
    //generate clock and synchronized reset for tx module
    ClockDividerIfc cdiv <- mkClockDivider(clocked_by clk, reset_by rst, clockDivisor);
    Reset rstSync <- mkAsyncReset(0, rst, cdiv.slowClock);

    UART_tx_ifc my_tx <- mkUART_tx8n1(clocked_by cdiv.slowClock, reset_by rstSync, clk, rst);

    // ------------------- RX ----------------------
    Integer clockDivisorRX = clockDivisor / valueOf(UARTRX_SAMPLE_SIZE);
    ClockDividerIfc cdivRX <- mkClockDivider(clocked_by clk, reset_by rstRX, clockDivisorRX);
    Reset rstSyncRX <- mkAsyncReset(0, rstRX, cdivRX.slowClock);
    UART_rx_ifc my_rx <- mkUART_rx8n1(clocked_by cdivRX.slowClock, reset_by rstSyncRX, clk, rstRX);

    Reg#(UInt#(64)) cnt <- mkReg(0);

    Reg#(UART_pkt) recv <- mkRegU(clocked_by clk, reset_by rst);

    rule cycle;
        cnt <= cnt + 1;
    endrule

    Stmt s = seq
        par
        while(True)
            action
                let y <- my_rx.data.get();
                recv <= y;
                $display("hello");
            endaction
        seq
        while(True)
            action 
                let x = my_tx.out_pin(); 
                my_rx.in_pin(x);
            endaction
        endseq
        seq
        $display("rx divisor: %d", clockDivisorRX);
        $display("Testing UART modules");
        // for(send_byte <= fromInteger(ascii_0); send_byte != fromInteger(ascii_9); send_byte <= send_byte + 1) seq
        //     my_tx.data.put(pack(send_byte));
        //     delay(100);
        // endseq
        my_tx.data.put(pack(8'h41)); 
        my_tx.data.put(pack(8'h50)); 
        my_tx.data.put(pack(8'h52)); 
        delay(200);
        $display("Done... ");
        $finish;
        endseq
        endpar
    endseq;

    mkAutoFSM(clocked_by clk, reset_by rst, s);

endmodule

endpackage