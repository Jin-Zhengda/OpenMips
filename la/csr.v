`include "define.v"

module csr (
    input wire clk,
    input wire rst,

    // read
    input wire read_en,
    input wire[`CSRAddrWidth] read_addr,
    output reg[`RegWidth] read_data,

    // write
    input wire write_en,
    input wire[`CSRAddrWidth] write_addr,    
    input wire[`RegWidth] write_data,

    // exception
    input wire is_exception,
    input wire[`ExceptionCauseWidth] exception_cause,
    input wire[`InstAddrWidth] exception_pc,
    input wire[`RegWidth] exception_addr,
    input wire is_ertn,
    input wire is_syscall_break,

    // interrupt
    input wire is_ipi,
    input wire[7: 0] is_hwi,

    // LLbit
    input wire LLbit_write_en,
    input wire LLbit_i, 
    output wire LLbit_o,

    // to id
    output wire[1: 0] CRMD_PLV,

    // to ctrl
    output wire[`InstAddrWidth] EENTRY_VA,
    output wire[`InstAddrWidth] ERA_PC,
    output wire[11: 0] ECFG_LIE,
    output wire[11: 0] ESTAT_IS,
    output wire CRMD_IE
);

    reg[`RegWidth] crmd;
    reg[`RegWidth] prmd;
    reg[`RegWidth] euem;
    reg[`RegWidth] ecfg;
    reg[`RegWidth] estat;
    reg[`RegWidth] era;
    reg[`RegWidth] badv;
    reg[`RegWidth] eentry;
    reg[`RegWidth] tlbidx;
    reg[`RegWidth] tlbhi;
    reg[`RegWidth] tlblo0;
    reg[`RegWidth] tlblo1;
    reg[`RegWidth] asid;
    reg[`RegWidth] pgdl;
    reg[`RegWidth] pgdh;
    reg[`RegWidth] pgd;
    reg[`RegWidth] cpuid;
    reg[`RegWidth] save0;
    reg[`RegWidth] save1;
    reg[`RegWidth] save2;
    reg[`RegWidth] save3;
    reg[`RegWidth] tid;
    reg[`RegWidth] tcfg;
    reg[`RegWidth] tval;
    reg[`RegWidth] ticlr;
    reg[`RegWidth] llbctl;
    reg[`RegWidth] tlbrentry;
    reg[`RegWidth] ctag;
    reg[`RegWidth] dmw0;
    reg[`RegWidth] dmw1;

    wire is_ti;

    assign CRMD_PLV = crmd[1: 0];

    assign EENTRY_VA = {eentry[31: 6], 6'b0};
    assign ERA_PC = era;
    assign ECFG_LIE = {ecfg[12: 11], ecfg[9: 0]};
    assign ESTAT_IS = {estat[12: 11], estat[9: 0]};

    // CRMD write
    always @(posedge clk) begin
        if (rst) begin
            crmd <= {{23{1'b0}}, 9'b000001000};
        end 
        else if (is_exception) begin
            crmd[1: 0] <= 2'b0; // PLV
            crmd[2] <= 1'b0; // IE
            if (exception_cause == `EXCEPTION_TLBR) begin
                crmd[3] <= 1'b0; // DA
                crmd[4] <= 1'b1; // PG
            end
        end 
        else if (is_ertn) begin
            crmd[1: 0] <= prmd[1: 0]; // PLV
            crmd[2] <= prmd[2]; // IE
            crmd[3] <= (estat[21: 16] == 6'b111111) ? 1'b0 : crmd[3]; // DA
            crmd[4] <= (estat[21: 16] == 6'b111111) ? 1'b1 : crmd[4]; // PG
        end
        else if (write_en && write_addr == `CSR_CRMD) begin
            crmd[8: 0] <= write_data[8: 0];
        end
        else begin
            crmd <= crmd;
        end
    end

    // PRMD write
    always @(posedge clk) begin
        if (rst) begin
            prmd <= 32'b0;
        end 
        else if (is_exception) begin
            prmd[1: 0] <= crmd[1: 0]; // PPLV
            prmd[2] <= crmd[2]; // PIE
        end
        else if (write_en && write_addr == `CSR_PRMD) begin
            prmd[2: 0] <= write_data[2: 0];
        end
        else begin
            prmd <= prmd;
        end
    end

    // EUEN write
    always @(posedge clk) begin
        if (rst) begin
            euem <= 32'b0;
        end 
        else if (write_en && write_addr == `CSR_EUEN) begin
            euem[0] <= write_data[0];
        end
        else begin
            euem <= euem;
        end
    end

    // ECFG write
    always @(posedge clk) begin
        if (rst) begin
            ecfg <= 32'b0;
        end 
        else if (write_en && write_addr == `CSR_ECFG) begin
            ecfg[9: 0] <= write_data[9: 0];
            ecfg[12: 11] <= write_data[12: 11];
        end
        else begin
            ecfg <= ecfg;
        end
    end

    // ESTAT write
    always @(posedge clk) begin
        if (rst) begin
            estat <= 32'b0;
        end 
        else if (is_exception) begin
            case (exception_cause)
                `EXCEPTION_INT: begin
                    estat[21: 16] <= 6'h0;
                    estat[30: 22] <= 9'b0;
                end
                `EXCEPTION_PIL: begin
                    estat[21: 16] <= 6'h1;
                    estat[30: 22] <= 9'b0;
                end
                `EXCEPTION_PIS: begin
                    estat[21: 16] <= 6'h2;
                    estat[30: 22] <= 9'b0;
                end
                `EXCEPTION_PIF: begin
                    estat[21: 16] <= 6'h3;
                    estat[30: 22] <= 9'b0;
                end
                `EXCEPTION_PME: begin
                    estat[21: 16] <= 6'h4;
                    estat[30: 22] <= 9'b0;
                end
                `EXCEPTION_PPI: begin
                    estat[21: 16] <= 6'h7;
                    estat[30: 22] <= 9'b0;
                end
                `EXCEPTION_ADEF: begin
                    estat[21: 16] <= 6'h8;
                    estat[30: 22] <= 9'b0;
                end
                `EXCEPTION_ADEM: begin
                    estat[21: 16] <= 6'h8;
                    estat[30: 22] <= 9'b1;
                end
                `EXCEPTION_ALE: begin
                    estat[21: 16] <= 6'h9;
                    estat[30: 22] <= 9'b0;
                end
                `EXCEPTION_SYS: begin
                    estat[21: 16] <= 6'hb;
                    estat[30: 22] <= 9'b0;
                end
                `EXCEPTION_BRK: begin
                    estat[21: 16] <= 6'hc;
                    estat[30: 22] <= 9'b0;
                end
                `EXCEPTION_INE: begin
                    estat[21: 16] <= 6'hd;
                    estat[30: 22] <= 9'b0;
                end
                `EXCEPTION_IPE: begin
                    estat[21: 16] <= 6'he;
                    estat[30: 22] <= 9'b0;
                end
                `EXCEPTION_FPD: begin
                    estat[21: 16] <= 6'hf;
                    estat[30: 22] <= 9'b0;
                end
                `EXCEPTION_FPE: begin
                    estat[21: 16] <= 6'h12;
                    estat[30: 22] <= 9'b0;
                end
                `EXCEPTION_TLBR: begin
                    estat[21: 16] <= 6'h3f;
                    estat[30: 22] <= 9'b0;
                end
                default: begin
                end 
            endcase
        end
        else if (write_en && write_addr == `CSR_ESTAT) begin
            estat[1: 0] <= write_data[1: 0];
        end
        else begin
            estat[1: 0] <= estat[1: 0];
            estat[9: 2] <= is_hwi;
            estat[10] <= estat[10];
            estat[11] <= is_ti;
            estat[12] <= is_ipi;
            estat[31: 13] <= estat[31: 13];
        end
    end

    // ERA write
    always @(posedge clk) begin
        if (rst) begin
            era <= 32'b0;
        end 
        else if (is_exception) begin
            if (is_syscall_break) begin
                era <= exception_pc + 4'h4;
            end
            else begin
                era <= exception_pc;
            end
        end
        else if (write_en && write_addr == `CSR_ERA) begin
            era <= write_data;
        end
        else begin
            era <= era;
        end
    end

    // BADV write
    always @(posedge clk) begin
        if (rst) begin
            badv <= 32'b0;
        end 
        else if (is_exception) begin
            case (exception_cause)
                `EXCEPTION_TLBR, `EXCEPTION_ALE, `EXCEPTION_PIL, `EXCEPTION_PIS, 
                `EXCEPTION_PIF, `EXCEPTION_PME, `EXCEPTION_PPI: begin
                    badv <= exception_addr;
                end 
                `EXCEPTION_ADEF: begin
                    badv <= exception_pc;
                end
                default: begin
                end
            endcase
        end
        else if (write_en && write_addr == `CSR_BADV) begin
            badv <= write_data;
        end
        else begin
            badv <= badv;
        end
    end

    // EENTRY write
    always @(posedge clk) begin
        if (rst) begin
            eentry <= 32'b0;
        end
        else if (write_en && write_addr == `CSR_EENTRY) begin
            eentry[31: 6] <= write_data[31: 6];
        end
        else begin
            eentry <= eentry;
        end
    end

    // CPUID write
    always @(posedge clk) begin
        if (rst) begin
            cpuid <= 32'b1;
        end
        else begin
            cpuid <= cpuid;
        end
    end

    // SAVE0 write
    always @(posedge clk) begin
        if (rst) begin
            save0 <= 32'b0;
        end
        else if (write_en && write_addr == `CSR_SAVE0) begin
            save0 <= write_data;
        end
        else begin
            save0 <= save0;
        end
    end

    // SAVE1 write
    always @(posedge clk) begin
        if (rst) begin
            save1 <= 32'b0;
        end
        else if (write_en && write_addr == `CSR_SAVE1) begin
            save1 <= write_data;
        end
        else begin
            save1 <= save1;
        end
    end

    // SAVE2 write
    always @(posedge clk) begin
        if (rst) begin
            save2 <= 32'b0;
        end
        else if (write_en && write_addr == `CSR_SAVE2) begin
            save2 <= write_data;
        end
        else begin
            save2 <= save2;
        end
    end

    // SAVE3 write
    always @(posedge clk) begin
        if (rst) begin
            save3 <= 32'b0;
        end
        else if (write_en && write_addr == `CSR_SAVE3) begin
            save3 <= write_data;
        end
        else begin
            save3 <= save3;
        end
    end

    // LLBCTL write
    always @(posedge clk) begin
        if (rst) begin
            llbctl <= 32'b0;
        end
        else if (llbctl[1]) begin
            llbctl[0] <= 1'b0;
            llbctl[1] <= 1'b0;
        end
        else if (is_ertn && llbctl[2] != 1'b1) begin
            llbctl[0] <= 1'b0;
            llbctl[2] <= 1'b0;
        end
        else if (LLbit_write_en) begin
            llbctl[0] <= LLbit_i;
        end
        else if (write_en && write_addr == `CSR_LLBCTL) begin
            llbctl[1] <= (write_data[1] == 1'b1) ? 1'b1: llbctl[1];
            llbctl[2] <= write_data[2];
        end
        else begin
            llbctl <= llbctl;
        end
    end

    assign LLbit_o = llbctl[0];

    // TID write
    always @(posedge clk) begin
        if (rst) begin
            tid <= cpuid;
        end
        else if (write_en && write_addr == `CSR_TID) begin
            tid <= write_data;
        end
        else begin
            tid <= tid;
        end
    end

    // TCFG write
    always @(posedge clk) begin
        if (rst) begin
            tcfg <= 32'b0;
        end
        else if (write_en && write_addr == `CSR_TCFG) begin
            tcfg <= write_data;
        end
        else begin
            tcfg <= tcfg;
        end
    end

    // TVAL write
    // csr counter
    wire csr_cnt_end;

    assign is_ti = (tval == 32'h0) && ~ticlr[0];

    assign csr_cnt_end = tcfg[0] && (tval == 32'h0) && ~is_ti;

    always @(posedge clk) begin
        if (rst) begin
            tval <= 32'hFFFFFFFF;
        end
        else if (csr_cnt_end) begin
            if (tcfg[1]) begin
                tval <= {tcfg[31: 2], 2'b0};
            end
            else begin
                tval <= tval;
            end
        end
        else if (tcfg[0] && ~is_ti) begin
            tval <= tval - 32'h1;
        end
        else begin
            tval <= tval;
        end
    end

    // TICLR write
    always @(posedge clk) begin
        if (rst) begin
            ticlr <= 32'b0;
        end
        else if (write_en && write_addr == `CSR_TICLR && write_data[0] == 1'b1) begin
            ticlr[0] <= write_data[0];
        end
        else begin
            ticlr <= 32'b0;
        end
    end

    // read
    always @(*) begin
        if (rst) begin
            read_data = 0;
        end 
        else if (read_en) begin
            case (read_addr)
                `CSR_CRMD: begin
                    read_data = crmd;
                end 
                `CSR_PRMD: begin
                    read_data = prmd;
                end
                `CSR_EUEN: begin
                    read_data = euem;
                end
                `CSR_ECFG: begin
                    read_data = ecfg;
                end
                `CSR_ESTAT: begin
                    read_data = estat;
                end
                `CSR_ERA: begin
                    read_data = era;
                end
                `CSR_BADV: begin
                    read_data = badv;
                end
                `CSR_EENTRY: begin
                    read_data = eentry;
                end
                `CSR_CPUID: begin
                    read_data = cpuid;
                end
                `CSR_SAVE0: begin
                    read_data = save0;
                end
                `CSR_SAVE1: begin
                    read_data = save1;
                end
                `CSR_SAVE2: begin
                    read_data = save2;
                end
                `CSR_SAVE3: begin
                    read_data = save3;
                end
                `CSR_LLBCTL: begin
                    read_data = llbctl;
                end
                `CSR_TID: begin
                    read_data = tid;
                end
                `CSR_TCFG: begin
                    read_data = tcfg;
                end
                `CSR_TVAL: begin
                    read_data = tval;
                end
                `CSR_TICLR: begin
                    read_data = ticlr;
                end
                default: begin
                    read_data = 32'b0;
                end
            endcase
        end
        else begin
            read_data = 32'b0;
        end
    end
    
endmodule