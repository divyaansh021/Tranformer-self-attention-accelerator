`timescale 1ns/1ps
module tb_matmul_ctrl;
    reg        clk,rst_n,start;
    reg  [3:0] n_valid,dk_valid;
    wire       acc_clr,running,done;
    wire [4:0] cycle_cnt;
    integer    pass_count,fail_count;

    matmul_ctrl #(.SIZE(8)) DUT (
        .clk(clk),.rst_n(rst_n),.start(start),
        .n_valid(n_valid),.dk_valid(dk_valid),
        .acc_clr(acc_clr),.running(running),
        .done(done),.cycle_cnt(cycle_cnt)
    );

    initial clk=0; always #5 clk=~clk;

    task chk_sig;
        input got,exp; input [8*40-1:0] nm;
        begin
            if(got===exp) begin $display("  PASS | %s",nm); pass_count=pass_count+1; end
            else          begin $display("  FAIL | %s | got=%b exp=%b",nm,got,exp); fail_count=fail_count+1; end
        end
    endtask

    task chk_int;
        input integer got,exp; input [8*40-1:0] nm;
        begin
            if(got===exp) begin $display("  PASS | %s | %0d",nm,got); pass_count=pass_count+1; end
            else          begin $display("  FAIL | %s | got=%0d exp=%0d",nm,got,exp); fail_count=fail_count+1; end
        end
    endtask

    task do_reset;
        begin rst_n=0;start=0; repeat(2)@(posedge clk); rst_n=1;@(posedge clk);#1; end
    endtask

    // Run one full sequence and count acc_clr, running, done cycles
    task run_seq;
        input [3:0] n,dk; input [8*20-1:0] lbl;
        integer exp_lat,acc_cnt,run_cnt,done_cnt,wd;
        begin
            exp_lat  = 2*n + dk - 2;
            acc_cnt=0; run_cnt=0; done_cnt=0; wd=0;
            n_valid=n; dk_valid=dk;
            start=1; @(posedge clk);#1; start=0;
            while(done_cnt==0 && wd<200) begin
                if(acc_clr)  acc_cnt  = acc_cnt+1;
                if(running)  run_cnt  = run_cnt+1;
                if(done)     done_cnt = done_cnt+1;
                @(posedge clk);#1; wd=wd+1;
            end
            $display("\n  [%s] N=%0d DK=%0d exp_lat=%0d",lbl,n,dk,exp_lat);
            chk_int(acc_cnt,  1,        "acc_clr fired once");
            chk_int(run_cnt,  exp_lat,  "running cycles");
            chk_int(done_cnt, 1,        "done fired once");
            @(posedge clk);#1;
        end
    endtask

    initial begin
        pass_count=0; fail_count=0;
        $display("==========================================");
        $display("  Testbench: matmul_ctrl (combinational acc_clr)");
        $display("==========================================");

        $display("\n--- Test 1: IDLE outputs low ---");
        do_reset;
        chk_sig(acc_clr,0,"acc_clr=0 in IDLE");
        chk_sig(running, 0,"running=0 in IDLE");
        chk_sig(done,    0,"done=0    in IDLE");

        $display("\n--- Test 2: N=3 DK=3 latency=7 ---");
        do_reset; run_seq(3,3,"N3_DK3");

        $display("\n--- Test 3: N=4 DK=4 latency=10 ---");
        do_reset; run_seq(4,4,"N4_DK4");

        $display("\n--- Test 4: N=8 DK=8 latency=22 ---");
        do_reset; run_seq(8,8,"N8_DK8");

        $display("\n--- Test 5: N=1 DK=1 latency=1 ---");
        do_reset; run_seq(1,1,"N1_DK1");

        $display("\n--- Test 6: acc_clr is combinational (no register delay) ---");
        do_reset;
        n_valid=4; dk_valid=4;
        // pulse start — in SAME cycle acc_clr should go high (combinational)
        start=1; @(posedge clk);#1; start=0;
        // now in CLEAR state — check acc_clr is immediately 1
        chk_sig(acc_clr,1,"acc_clr=1 in CLEAR state (combinational)");
        @(posedge clk);#1; // RUN starts
        chk_sig(acc_clr,0,"acc_clr=0 in RUN state");
        @(posedge clk);#1; // running registered — needs 1 cycle to appear
        
        chk_sig(running,1,"running=1 in RUN state");

        $display("\n--- Test 7: back-to-back ---");
        do_reset;
        n_valid=4; dk_valid=4;
        start=1;@(posedge clk);#1;start=0;
        while(!done)begin @(posedge clk);#1;end
        chk_sig(done,1,"first done");
        @(posedge clk);#1;
        start=1;@(posedge clk);#1;start=0;
        while(!done)begin @(posedge clk);#1;end
        chk_sig(done,1,"second done");

        $display("\n==========================================");
        $display("  Results: %0d PASSED, %0d FAILED",pass_count,fail_count);
        if(fail_count==0) $display("  ALL TESTS PASSED");
        else              $display("  SOME TESTS FAILED");
        $display("==========================================");
        $finish;
    end
    initial begin $dumpfile("tb_matmul_ctrl.vcd");$dumpvars(0,tb_matmul_ctrl);end
    initial begin #500000;$display("TIMEOUT");$finish;end
endmodule
