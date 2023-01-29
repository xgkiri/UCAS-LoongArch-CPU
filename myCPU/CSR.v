module CSR(
    input wire clk,
    input wire reset,
    input wire csr_re,
    input wire csr_we,
    input wire valid_WB,
    input wire [13:0]csr_num,
    input wire [31:0]csr_wvalue,
    input wire [31:0]csr_wmask_WB,
    //input wire has_int,
    //input wire [7:0]hw_int_in,
    input wire ertn_flush,
    input wire ex_WB,
    input wire [31:0]pc_WB,
    input wire [31:0]vaddr_WB,
    input wire [5:0]ecode_WB,
    input wire [8:0]esubcode_WB,
    input wire ex_refill,//重填异常
    input wire [97:0]csr_tlb_input,//TLB输出到CSR
    //output
    output wire [31:0]csr_rvalue,
    output wire [31:0]ex_entry,
    output wire [11:0]csr_estat_is_data,
    output wire [11:0]csr_ecfg_lie_data,
    output wire csr_crmd_ie_data,
    output wire [1:0]csr_crmd_plv_data,
    output wire [97:0]csr_tlb_output,//CSR输出到TLB
    output wire [31:0]csr_asid_rvalue,
    output wire [31:0]csr_tlbehi_rvalue,
    output wire [31:0]csr_crmd_rvalue,
    output wire [31:0]csr_dmw0_rvalue,
    output wire [31:0]csr_dmw1_rvalue,
    output wire [31:0]csr_tlbrentry_rvalue
);

/* 添加宏定义 */
// E(SUB)CODE
`define ECODE_TLBR      6'h3F//TLB重填例外
`define ECODE_PIL       6'h1 //load操作页无效例外
`define ECODE_PIS       6'h2 //store操作页无效例外
`define ECODE_PIF       6'h3 //取值操作页无效例外
`define ECODE_PME       6'h4 //页写允许例外
`define ECODE_PPI       6'h7 //页特权等级不合规例外
`define ECODE_ADE       6'h8 //地址错例外
`define ECODE_ALE       6'h9 //地址非对齐例外
`define ESUBCODE_ADEF   6'h0 //取指地址错例外

// CRMD
`define CSR_CRMD        14'h0
`define CSR_CRMD_PLV    1:0
`define CSR_CRMD_PIE    2
`define CSR_CRMD_DA     3
`define CSR_CRMD_PG     4
`define CSR_CRMD_DATF   6:5
`define CSR_CRMD_DATM   8:7
// PRMD
`define CSR_PRMD        14'h1
`define CSR_PRMD_PPLV   1:0
`define CSR_PRMD_PIE    2

// ECFG
`define CSR_ECFG        14'h4
`define CSR_ECFG_LIE    12:0

// ESTAT
`define CSR_ESTAT       14'h5
`define CSR_ESTAT_IS10  1:0
`define CSR_TICLR       14'h44
`define CSR_TICLR_CLR   0 

// ERA 
`define CSR_ERA         14'h6
`define CSR_ERA_PC      31:0

// BADV
`define CSR_BADV        14'h7

// EENTRY
`define CSR_EENTRY      14'hc
`define CSR_EENTRY_VA   31:6

// SAVE
`define CSR_SAVE0       14'h30
`define CSR_SAVE1       14'h31
`define CSR_SAVE2       14'h32
`define CSR_SAVE3       14'h33
`define CSR_SAVE_DATA   31:0

//TID
`define CSR_TID         14'h40
`define CSR_TID_TID     31:0

//TCFG
`define CSR_TCFG        14'h41    
`define CSR_TCFG_EN     0
`define CSR_TCFG_PERIOD 1
`define CSR_TCFG_INITV  31:2

//TVAL
`define CSR_TVAL        14'h42
`define CSR_TCFG_INITVAL 31:2

//TLBIDX
`define CSR_TLBIDX      14'h10
`define CSR_TLBIDX_INDEX 4:0
`define CSR_TLBIDX_PS    29:24
`define CSR_TLBIDX_NE    31
//TLBEHI
`define CSR_TLBEHI      14'h11
`define CSR_TLBEHI_VPPN  31:13

//TLBELO0
`define CSR_TLBELO0     14'h12
`define CSR_TLBELO0_V   0
`define CSR_TLBELO0_D   1
`define CSR_TLBELO0_PLV 3:2
`define CSR_TLBELO0_MAT 5:4
`define CSR_TLBELO0_G   6
`define CSR_TLBELO0_PPN 31:8

//TLBELO1
`define CSR_TLBELO1     14'h13
`define CSR_TLBELO1_V   0
`define CSR_TLBELO1_D   1
`define CSR_TLBELO1_PLV 3:2
`define CSR_TLBELO1_MAT 5:4
`define CSR_TLBELO1_G   6
`define CSR_TLBELO1_PPN 31:8

//ASID
`define CSR_ASID        14'h18
`define CSR_ASID_ASID   9:0
`define CSR_ASID_ASIDBITS 23:16

//TLBRENTRY
`define CSR_TLBRENTRY   14'h88
`define CSR_TLBRENTRY_PA 31:6

//DMW
`define CSR_DMW0        14'h180
`define CSR_DMW1        14'h181 
`define CSR_DMW_PLV0    0
`define CSR_DMW_PLV3    3
`define CSR_DMW_MAT     5:4
`define CSR_DMW_PSEG    27:25
`define CSR_DMW_VSEG    31:29

// CRMD defination
wire [31:0] csr_crmd;
reg  [1:0]csr_crmd_plv;
reg  csr_crmd_ie;
reg  csr_crmd_da;
reg  csr_crmd_pg;
reg  [1:0]csr_crmd_datf;
reg  [1:0]csr_crmd_datm;
reg  [22:0]csr_crmd_rem = 23'b0;
assign csr_crmd = {csr_crmd_rem,csr_crmd_datm,csr_crmd_datf,csr_crmd_pg,csr_crmd_da,csr_crmd_ie,csr_crmd_plv};

//PRMD defination
wire [31:0] csr_prmd;
reg  [1:0]  csr_prmd_pplv;
reg         csr_prmd_pie;
reg  [28:0] csr_prmd_rem = 29'b0;
wire [31:0] csr_prmd_rvalue;
assign csr_prmd = {csr_prmd_rem,csr_prmd_pie,csr_prmd_pplv};

//ECFG defination
wire [31:0] csr_ecfg;
reg  [12:0] csr_ecfg_lie;
assign csr_ecfg = {19'b0, csr_ecfg_lie};

//ESTAT defination
wire [31:0] csr_estat;
reg  [12:0] csr_estat_is;
reg  [5:0]  csr_estat_ecode;
reg  [8:0]  csr_estat_esubcode;
wire [31:0] csr_estat_rvalue;
assign csr_estat = {1'b0,csr_estat_esubcode,csr_estat_ecode,3'b0,csr_estat_is};

//ERA defination
wire [31:0] csr_era;
reg [31:0] csr_era_pc;
assign csr_era = {csr_era_pc};

//BADV defination
wire [31:0] csr_badv;
reg  [31:0] csr_badv_vaddr;
wire ex_addr_err_WB;
assign csr_badv = csr_badv_vaddr;

//EENTRY defination
wire [31:0] csr_eentry;
reg  [25:0] csr_eentry_va;
assign csr_eentry = {csr_eentry_va,6'b0};

//SAVEN0~3
reg [31:0] csr_save0_data;
reg [31:0] csr_save1_data;
reg [31:0] csr_save2_data;
reg [31:0] csr_save3_data;

//TID defination
reg [31:0] csr_tid_tid;

//TCFG and TVAL defination
reg csr_tcfg_en;
reg csr_tcfg_periodic;
reg [29:0] csr_tcfg_initval;
wire [31:0] tcfg_next_value;
wire [31:0] csr_tval;
reg [31:0] timer_cnt;
wire [31:0] csr_tcfg_rvalue;
assign tcfg_next_value = csr_wmask_WB[31:0] & csr_wvalue[31:0]
                       | ~csr_wmask_WB[31:0] & {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

//TICLR defination
wire csr_ticlr_clr;
assign csr_ticlr_clr = 1'b0;
/*ERTN指令会更改该寄存器，但是任务要求没有对该寄存器的要求，故先注释掉，有空余时间可以补全
//LLBCTL defination
wire [31:0]csr_llbctl;
reg csr_llbctl_rollb;
reg csr_llbctl_wcllb;
reg csr_llbctl_klo;
assign csr_llbctl = {csr_llbctl_rollb,csr_llbctl_wcllb,csr_llbctl_klo,29'b0};
*/

//TLBIDX defination
reg [3:0] csr_tlbidx_index;
reg [5:0] csr_tlbidx_ps;
reg       csr_tlbidx_ne;
wire [31:0] csr_tlbidx_rvalue;

//TLBEHI defination
reg [18:0] csr_tlbehi_vppn;

//TLBELO0 defination
reg        csr_tlbelo0_v;
reg        csr_tlbelo0_d;
reg [1:0]  csr_tlbelo0_plv;
reg [1:0]  csr_tlbelo0_mat;
reg        csr_tlbelo0_g;
reg [23:0] csr_tlbelo0_ppn;
wire [31:0] csr_tlbelo0_rvalue;

//TLBELO1 defination
reg        csr_tlbelo1_v;  
reg        csr_tlbelo1_d; 
reg [1:0]  csr_tlbelo1_plv;
reg [1:0]  csr_tlbelo1_mat;
reg        csr_tlbelo1_g;  
reg [24:0] csr_tlbelo1_ppn;
wire [31:0] csr_tlbelo1_rvalue;

//ASID defination
reg [9:0]  csr_asid_asid;
reg [7:0]  csr_asid_asidbits;

//TLBRENTRY defination
reg [25:0] csr_tlbrentry_pa;

//DMW defination
reg        csr_dmw0_plv0;
reg        csr_dmw0_plv3;
reg  [1:0] csr_dmw0_mat;
reg  [2:0] csr_dmw0_pseg;
reg  [2:0] csr_dmw0_vseg;

reg        csr_dmw1_plv0;
reg        csr_dmw1_plv3;
reg  [1:0] csr_dmw1_mat;
reg  [2:0] csr_dmw1_pseg;
reg  [2:0] csr_dmw1_vseg;


//TLB相关信号定义
wire        inst_tlbfill;
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        s1_found;
wire [ 3:0] s1_index;
wire        we;
wire [ 3:0] w_index;
wire        w_e;
wire [18:0] w_vppn;
wire [ 5:0] w_ps;
wire [ 9:0] w_asid;
wire        w_g;
wire [19:0] w_ppn0;
wire [ 1:0] w_plv0;
wire [ 1:0] w_mat0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_ppn1;
wire [ 1:0] w_plv1;
wire [ 1:0] w_mat1;
wire        w_d1;
wire        w_v1;
wire [ 3:0] r_index;
wire        r_e;
wire [18:0] r_vppn;
wire [ 5:0] r_ps;
wire [ 9:0] r_asid;
wire        r_g;
wire [19:0] r_ppn0;
wire [ 1:0] r_plv0;
wire [ 1:0] r_mat0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_ppn1;
wire [ 1:0] r_plv1;
wire [ 1:0] r_mat1;
wire        r_d1;
wire        r_v1;
reg [ 3:0] tlbfill_index;

assign  {
          inst_tlbwr,//97
          inst_tlbfill,//96
          inst_tlbsrch,//95
          inst_tlbrd,  //94
          s1_found,    //93
          s1_index,    //92:89
          r_e,         //88
          r_vppn,      //87:69
          r_ps,        //68:63
          r_asid,      //62:53
          r_g,         //52
          r_ppn0,      //51:32
          r_plv0,      //31:30
          r_mat0,      //29:28
          r_d0,        //27
          r_v0,        //26
          r_ppn1,      //25:6
          r_plv1,      //5:4
          r_mat1,      //3:2
          r_d1,        //1
          r_v1         //0
        } = csr_tlb_input;

assign csr_tlb_output   = {we,     //97
                        w_index,//96:93
                        w_e,    //92
                        w_vppn, //91:73
                        w_ps,   //72:67
                        w_asid, //66:57
                        w_g,    //56
                        w_ppn0, //55:36
                        w_plv0, //35:34
                        w_mat0, //33:32
                        w_d0,   //31
                        w_v0,   //30
                        w_ppn1, //29:10
                        w_plv1, //9:8
                        w_mat1, //7:6
                        w_d1,   //5
                        w_v1,   //4
                        r_index //3:0
                       };


//CRMD module
always @(posedge clk)begin
    if(reset)
        csr_crmd_plv <= 2'b0;
    else if(ex_WB)
        csr_crmd_plv <= 2'b0;
    else if(ertn_flush)
        csr_crmd_plv <= csr_prmd_pplv;
    else if(csr_we && csr_num == `CSR_CRMD)
        csr_crmd_plv <= csr_wmask_WB[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV] | ~csr_wmask_WB[`CSR_CRMD_PLV] & csr_crmd_plv;
end

always @(posedge clk) begin
    if(reset)
        csr_crmd_ie <= 1'b0;
    else if(ex_WB)
        csr_crmd_ie <= 1'b0;
    else if(ertn_flush)
        csr_crmd_ie <= csr_prmd_pie;
    else if(csr_we && csr_num == `CSR_CRMD)
        csr_crmd_ie <= csr_wmask_WB[`CSR_CRMD_PIE] & csr_wvalue[`CSR_CRMD_PIE] | ~csr_wmask_WB[`CSR_CRMD_PIE] & csr_crmd_ie;
end

always @(posedge clk)begin
    if(reset)begin
        csr_crmd_da <= 1'b1;
    end
    else if(ex_refill)begin
        csr_crmd_da <= 1'b1;
    end
    else if(ertn_flush && csr_estat_ecode == `ECODE_TLBR )begin
        csr_crmd_da <= 1'b0;
    end
    else if(csr_we && csr_num == `CSR_CRMD)begin
        csr_crmd_da <= csr_wmask_WB[`CSR_CRMD_DA] & csr_wvalue[`CSR_CRMD_DA] | ~csr_wmask_WB[`CSR_CRMD_DA] & csr_crmd_da;
    end
end

always @(posedge clk)begin
    if(reset)begin
        csr_crmd_pg <= 1'b0;
    end
    else if(ex_refill)begin
        csr_crmd_pg <= 1'b0;
    end
    else if(ertn_flush && csr_estat_ecode == `ECODE_TLBR )begin
        csr_crmd_pg <= 1'b1;
    end
    else if(csr_we && csr_num == `CSR_CRMD)begin
        csr_crmd_pg <= csr_wmask_WB[`CSR_CRMD_PG] & csr_wvalue[`CSR_CRMD_PG] | ~csr_wmask_WB[`CSR_CRMD_PG] & csr_crmd_pg;
    end
end

// DATF和DATM理论上需要在PG位被置1时同时置为01
always @(posedge clk)begin
    if(reset)begin
        csr_crmd_datf <= 1'b0;
    end
    else if(csr_we && csr_num == `CSR_CRMD)begin
        csr_crmd_datf <= csr_wmask_WB[`CSR_CRMD_DATF] & csr_wvalue[`CSR_CRMD_DATF] | ~csr_wmask_WB[`CSR_CRMD_DATF] & csr_crmd_datf;
    end
end

always @(posedge clk)begin
    if(reset)begin
        csr_crmd_datm <= 1'b0;
    end
    else if(csr_we && csr_num == `CSR_CRMD)begin
        csr_crmd_datm <= csr_wmask_WB[`CSR_CRMD_DATM] & csr_wvalue[`CSR_CRMD_DATM] | ~csr_wmask_WB[`CSR_CRMD_DATM] & csr_crmd_datm;
    end
end

//PRMD module
always @(posedge clk) begin
    if (ex_WB) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie  <= csr_crmd_ie;
    end
    else if (csr_we && csr_num == `CSR_PRMD) begin
        csr_prmd_pplv <= csr_wmask_WB[`CSR_PRMD_PPLV]&csr_wvalue[`CSR_PRMD_PPLV]
                      | ~csr_wmask_WB[`CSR_PRMD_PPLV]&csr_prmd_pplv;
        csr_prmd_pie  <= csr_wmask_WB[`CSR_PRMD_PIE]&csr_wvalue[`CSR_PRMD_PIE]
                      | ~csr_wmask_WB[`CSR_PRMD_PIE]&csr_prmd_pie;
    end
end

//ECFG module
always @(posedge clk) begin
    if (reset)
        csr_ecfg_lie <= 13'b0;
    else if (csr_we && csr_num == `CSR_ECFG)
        csr_ecfg_lie <= csr_wmask_WB[`CSR_ECFG_LIE] & csr_wvalue[`CSR_ECFG_LIE]
                     | ~csr_wmask_WB[`CSR_ECFG_LIE] & csr_ecfg_lie;
end

//ESTAT module
always @(posedge clk)begin
    if(reset)
        csr_estat_is[1:0] <= 2'b0;
    else if(csr_we && csr_num == `CSR_ESTAT)
        csr_estat_is[1:0] <= csr_wmask_WB[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10] | ~csr_wmask_WB[`CSR_ESTAT_IS10] & csr_estat_is[1:0];
    
    csr_estat_is[9:2]     <= 8'b0;//hw_int_in[7:0];//8个硬中断的中断状态位
    csr_estat_is[10]      <= 1'b0;

    if(timer_cnt[31:0]==32'b0)
        csr_estat_is[11] <= 1'b1;//exp13处理定时器中断状态位
    if(csr_we && csr_num == `CSR_TICLR && csr_wmask_WB[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR])//����TICLR��CLR(??0??)�ж�
        csr_estat_is[11] <= 1'b0;
    
    csr_estat_is[12] <= 1'b0;//核间中断不需要处理ipi_int_in;
end

always @(posedge clk)begin
    if(ex_WB)begin
        csr_estat_ecode    <= ecode_WB;
        csr_estat_esubcode <= esubcode_WB;
    end
end

//ERA module
always @(posedge clk)begin
    if(ex_WB)
        csr_era_pc <= pc_WB;
    else if(csr_we && csr_num == `CSR_ERA)
        csr_era_pc <= csr_wmask_WB[`CSR_ERA_PC]&csr_wvalue[`CSR_ERA_PC] | ~csr_wmask_WB[`CSR_ERA_PC]&csr_era_pc;
end

//BADV module
assign ex_addr_err_WB = ecode_WB == `ECODE_ADE || ecode_WB == `ECODE_ALE || ecode_WB == `ECODE_TLBR || ecode_WB == `ECODE_PIF || ecode_WB == `ECODE_PIS || ecode_WB == `ECODE_PIL || ecode_WB == `ECODE_PME || ecode_WB == `ECODE_PPI;

always @(posedge clk)begin
    if (ex_WB && ex_addr_err_WB) begin
        csr_badv_vaddr <= (ecode_WB == `ECODE_ADE && esubcode_WB == `ESUBCODE_ADEF || ecode_WB == `ECODE_PIF) ? pc_WB : vaddr_WB;
    end
end

//EENTRY module
always @(posedge clk)begin
    if(csr_we && csr_num == `CSR_EENTRY)
        csr_eentry_va <= csr_wmask_WB[`CSR_EENTRY_VA]&csr_wvalue[`CSR_EENTRY_VA] | ~csr_wmask_WB[`CSR_EENTRY_VA]&csr_eentry_va;
end

//SAVEN module
always @(posedge clk)begin
    if(csr_we && csr_num == `CSR_SAVE0)
        csr_save0_data <= csr_wmask_WB[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] | ~csr_wmask_WB[`CSR_SAVE_DATA]&csr_save0_data;
    else if(csr_we && csr_num == `CSR_SAVE1)
        csr_save1_data <= csr_wmask_WB[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] | ~csr_wmask_WB[`CSR_SAVE_DATA]&csr_save1_data;
    else if(csr_we && csr_num == `CSR_SAVE2)
        csr_save2_data <= csr_wmask_WB[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] | ~csr_wmask_WB[`CSR_SAVE_DATA]&csr_save2_data;
    else if(csr_we && csr_num == `CSR_SAVE3)
        csr_save3_data <= csr_wmask_WB[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] | ~csr_wmask_WB[`CSR_SAVE_DATA]&csr_save3_data;
end
//TID module
always @(posedge clk) begin
    if(reset)
        csr_tid_tid <= 32'h0;
    else if(csr_we && csr_num == `CSR_TID)
        csr_tid_tid <= csr_wmask_WB[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID] | ~csr_wmask_WB[`CSR_TID_TID] & csr_tid_tid;
end

//TCFG module
always @(posedge clk) begin
    if(reset)
        csr_tcfg_en <= 1'b0;
    else if(csr_we && csr_num == `CSR_TCFG)
        csr_tcfg_en <= csr_wmask_WB[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN]
                    | ~csr_wmask_WB[`CSR_TCFG_EN] & csr_tcfg_en;
    
    if(csr_we && csr_num == `CSR_TCFG)begin
        csr_tcfg_periodic <= csr_wmask_WB[`CSR_TCFG_PERIOD] & csr_wvalue[`CSR_TCFG_PERIOD]
                          | ~csr_wmask_WB[`CSR_TCFG_PERIOD] & csr_tcfg_periodic;
        csr_tcfg_initval <= csr_wmask_WB[`CSR_TCFG_INITV] & csr_wvalue[`CSR_TCFG_INITV]
                         | ~csr_wmask_WB[`CSR_TCFG_INITV] & csr_tcfg_initval;
    end
end

//TVAL module
always @(posedge clk) begin
    if(reset)
        timer_cnt <= 32'hffffffff;
    else if(csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN]) begin
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
    end
    else if(csr_tcfg_en && timer_cnt != 32'hffffffff)begin
        if(timer_cnt[31:0] == 32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        else
            timer_cnt <= timer_cnt - 1'b1;
    end
end
assign csr_tval = timer_cnt[31:0];

assign csr_estat_is_data = csr_estat_is;
assign csr_ecfg_lie_data = csr_ecfg_lie;
assign csr_crmd_ie_data = csr_crmd_ie;
assign csr_crmd_plv_data = csr_crmd_plv;

//TLBIDX module
always @(posedge clk)begin
    if(reset)begin
        csr_tlbidx_index <= 4'b0;
    end
    else if(inst_tlbsrch && s1_found)begin
        csr_tlbidx_index <= s1_index;
    end
    else if(csr_we && csr_num == `CSR_TLBIDX)begin
        csr_tlbidx_index <= csr_wmask_WB[`CSR_TLBIDX_INDEX]&csr_wvalue[`CSR_TLBIDX_INDEX] | ~csr_wmask_WB[`CSR_TLBIDX_INDEX]&csr_tlbidx_index;
    end
end

always @(posedge clk)begin
    if(reset)begin
        csr_tlbidx_ps <= 6'b0;
    end
    else if(inst_tlbrd && r_e)begin
        csr_tlbidx_ps <= r_ps;
    end
    else if(inst_tlbrd && ~r_e)begin
        csr_tlbidx_ps <= 6'b0;
    end
    else if(csr_we && csr_num == `CSR_TLBIDX)begin
        csr_tlbidx_ps <= csr_wmask_WB[`CSR_TLBIDX_PS]&csr_wvalue[`CSR_TLBIDX_PS] | ~csr_wmask_WB[`CSR_TLBIDX_PS]&csr_tlbidx_ps;
    end
end

always @(posedge clk)begin
    if(reset)begin
        csr_tlbidx_ne <= 1'b0;
    end
    else if(inst_tlbsrch && s1_found)begin
        csr_tlbidx_ne <= 1'b0;
    end
    else if(inst_tlbsrch && ~s1_found)begin
        csr_tlbidx_ne <= 1'b1;
    end
    else if(valid_WB && inst_tlbrd)begin
        csr_tlbidx_ne <= ~r_e;
    end
    else if(csr_we && csr_num==`CSR_TLBIDX)begin
        csr_tlbidx_ne <= csr_wmask_WB[`CSR_TLBIDX_NE]&csr_wvalue[`CSR_TLBIDX_NE] | ~csr_wmask_WB[`CSR_TLBIDX_NE]&csr_tlbidx_ne;
    end
end 

//TLBEHI module
wire record_vppn = ecode_WB == `ECODE_TLBR || ecode_WB == `ECODE_PIL || ecode_WB == `ECODE_PIS || ecode_WB == `ECODE_PIF || ecode_WB == `ECODE_PME || ecode_WB == `ECODE_PPI;

always @(posedge clk)begin
    if(reset)begin
        csr_tlbehi_vppn <= 19'b0;
    end
    else if(inst_tlbrd && r_e)begin
        csr_tlbehi_vppn <= r_vppn;
    end
    else if(inst_tlbrd && ~r_e)begin
        csr_tlbehi_vppn <= 0;
    end
    else if(ex_WB && ~ertn_flush && record_vppn)begin
        csr_tlbehi_vppn <= ecode_WB == `ECODE_PIF ? pc_WB[31:13] : vaddr_WB[31:13];
    end
    else if(csr_we && csr_num == `CSR_TLBEHI)begin
        csr_tlbehi_vppn <= csr_wmask_WB[`CSR_TLBEHI_VPPN]&csr_wvalue[`CSR_TLBEHI_VPPN] | ~csr_wmask_WB[`CSR_TLBEHI_VPPN]&csr_tlbehi_vppn;
    end
end

//TLBELO0 module
always @(posedge clk)begin
    if(reset) begin
        csr_tlbelo0_v   <= 1'b0;
        csr_tlbelo0_d   <= 1'b0;
        csr_tlbelo0_plv <= 2'b0;
        csr_tlbelo0_mat <= 2'b0;
        csr_tlbelo0_g   <= 1'b0;
        csr_tlbelo0_ppn <= 23'b0;
    end
    else if(inst_tlbrd && r_e) begin
        csr_tlbelo0_v   <= r_v0;
        csr_tlbelo0_d   <= r_d0;
        csr_tlbelo0_plv <= r_plv0;
        csr_tlbelo0_mat <= r_mat0;
        csr_tlbelo0_g   <= r_g;
        csr_tlbelo0_ppn <= r_ppn0;
    end
    else if(inst_tlbrd && ~r_e) begin
        csr_tlbelo0_v   <= 0;
        csr_tlbelo0_d   <= 0;
        csr_tlbelo0_plv <= 0;
        csr_tlbelo0_mat <= 0;
        csr_tlbelo0_g   <= 0;
        csr_tlbelo0_ppn <= 0;
    end   
    else if(csr_we && csr_num == `CSR_TLBELO0)begin
        csr_tlbelo0_v   <= csr_wmask_WB[`CSR_TLBELO0_V] & csr_wvalue[`CSR_TLBELO0_V]| ~csr_wmask_WB[`CSR_TLBELO0_V] & csr_tlbelo0_v; 
        csr_tlbelo0_d   <= csr_wmask_WB[`CSR_TLBELO0_D] & csr_wvalue[`CSR_TLBELO0_D]| ~csr_wmask_WB[`CSR_TLBELO0_D] & csr_tlbelo0_d;
        csr_tlbelo0_plv <= csr_wmask_WB[`CSR_TLBELO0_PLV] & csr_wvalue[`CSR_TLBELO0_PLV]| ~csr_wmask_WB[`CSR_TLBELO0_PLV] & csr_tlbelo0_plv;
        csr_tlbelo0_mat <= csr_wmask_WB[`CSR_TLBELO0_MAT] & csr_wvalue[`CSR_TLBELO0_MAT]| ~csr_wmask_WB[`CSR_TLBELO0_MAT] & csr_tlbelo0_mat;
        csr_tlbelo0_g   <= csr_wmask_WB[`CSR_TLBELO0_G] & csr_wvalue[`CSR_TLBELO0_G]| ~csr_wmask_WB[`CSR_TLBELO0_G] & csr_tlbelo0_g;  
        csr_tlbelo0_ppn <= csr_wmask_WB[`CSR_TLBELO0_PPN] & csr_wvalue[`CSR_TLBELO0_PPN]| ~csr_wmask_WB[`CSR_TLBELO0_PPN] & csr_tlbelo0_ppn;
    end
end
always @(posedge clk)begin
    if(reset) begin
        csr_tlbelo1_v   <= 1'b0;
        csr_tlbelo1_d   <= 1'b0;
        csr_tlbelo1_plv <= 2'b0;
        csr_tlbelo1_mat <= 2'b0;
        csr_tlbelo1_g   <= 1'b0;
        csr_tlbelo1_ppn <= 23'b0;
    end
    else if(inst_tlbrd && r_e) begin
        csr_tlbelo1_v   <= r_v1;
        csr_tlbelo1_d   <= r_d1;
        csr_tlbelo1_plv <= r_plv1;
        csr_tlbelo1_mat <= r_mat1;
        csr_tlbelo1_g   <= r_g;
        csr_tlbelo1_ppn <= r_ppn1;
    end
    else if(inst_tlbrd && ~r_e) begin
        csr_tlbelo1_v   <= 0;
        csr_tlbelo1_d   <= 0;
        csr_tlbelo1_plv <= 0;
        csr_tlbelo1_mat <= 0;
        csr_tlbelo1_g   <= 0;
        csr_tlbelo1_ppn <= 0;
    end 
    else if(csr_we&& csr_num == `CSR_TLBELO1)begin
        csr_tlbelo1_v   <= csr_wmask_WB[`CSR_TLBELO1_V] & csr_wvalue[`CSR_TLBELO1_V]| ~csr_wmask_WB[`CSR_TLBELO1_V] & csr_tlbelo1_v; 
        csr_tlbelo1_d   <= csr_wmask_WB[`CSR_TLBELO1_D] & csr_wvalue[`CSR_TLBELO1_D]| ~csr_wmask_WB[`CSR_TLBELO1_D] & csr_tlbelo1_d;
        csr_tlbelo1_plv <= csr_wmask_WB[`CSR_TLBELO1_PLV] & csr_wvalue[`CSR_TLBELO1_PLV]| ~csr_wmask_WB[`CSR_TLBELO1_PLV] & csr_tlbelo1_plv;
        csr_tlbelo1_mat <= csr_wmask_WB[`CSR_TLBELO1_MAT] & csr_wvalue[`CSR_TLBELO1_MAT]| ~csr_wmask_WB[`CSR_TLBELO1_MAT] & csr_tlbelo1_mat;
        csr_tlbelo1_g   <= csr_wmask_WB[`CSR_TLBELO1_G] & csr_wvalue[`CSR_TLBELO1_G]| ~csr_wmask_WB[`CSR_TLBELO1_G] & csr_tlbelo1_g;  
        csr_tlbelo1_ppn <= csr_wmask_WB[`CSR_TLBELO1_PPN] & csr_wvalue[`CSR_TLBELO1_PPN]| ~csr_wmask_WB[`CSR_TLBELO1_PPN] & csr_tlbelo1_ppn;
    end
end

//ASID module
always @(posedge clk)begin
    if(reset)begin
        csr_asid_asid <= 10'b0;
    end
    else if(inst_tlbrd && r_e)begin
        csr_asid_asid <= r_asid;
    end
    else if(inst_tlbrd && ~r_e)begin
        csr_asid_asid <= 0;
    end
    else if(csr_we && csr_num == `CSR_ASID)begin
        csr_asid_asid <= csr_wmask_WB[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID]| ~csr_wmask_WB[`CSR_ASID_ASID] & csr_asid_asid;
    end
end

//TLBENTRY module
always @(posedge clk)begin
    if(reset)begin
        csr_tlbrentry_pa <= 26'b0;
    end
    else if(csr_we && csr_num == `CSR_TLBRENTRY)begin
        csr_tlbrentry_pa <= csr_wmask_WB[`CSR_TLBRENTRY_PA] & csr_wvalue[`CSR_TLBRENTRY_PA]| ~csr_wmask_WB[`CSR_TLBRENTRY_PA] & csr_tlbrentry_pa;
    end
end

//DMW module
always @(posedge clk)begin
    if (reset) begin
        csr_dmw0_plv0 <= 1'b0;
        csr_dmw0_plv3 <= 1'b0;
        csr_dmw0_mat  <= 2'b0;
        csr_dmw0_pseg <= 3'b0;
        csr_dmw0_vseg <= 3'b0;
    end
    else if (csr_we & (csr_num == `CSR_DMW0)) begin
        csr_dmw0_plv0 <= csr_wmask_WB[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]  | ~csr_wmask_WB[`CSR_DMW_PLV0] & csr_dmw0_plv0;
        csr_dmw0_plv3 <= csr_wmask_WB[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]  | ~csr_wmask_WB[`CSR_DMW_PLV3] & csr_dmw0_plv3;
        csr_dmw0_mat  <= csr_wmask_WB[`CSR_DMW_MAT]  & csr_wvalue[`CSR_DMW_MAT]  | ~csr_wmask_WB[`CSR_DMW_MAT]  & csr_dmw0_mat;
        csr_dmw0_pseg <= csr_wmask_WB[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]  | ~csr_wmask_WB[`CSR_DMW_PSEG] & csr_dmw0_pseg;
        csr_dmw0_vseg <= csr_wmask_WB[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]  | ~csr_wmask_WB[`CSR_DMW_VSEG] & csr_dmw0_vseg;
    end
end

always @(posedge clk)begin
    if (reset) begin
        csr_dmw1_plv0 <= 1'b0;
        csr_dmw1_plv3 <= 1'b0;
        csr_dmw1_mat  <= 2'b0;
        csr_dmw1_pseg <= 3'b0;
        csr_dmw1_vseg <= 3'b0;
    end
    else if (csr_we & (csr_num == `CSR_DMW1)) begin
        csr_dmw1_plv0 <= csr_wmask_WB[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]  | ~csr_wmask_WB[`CSR_DMW_PLV0] & csr_dmw0_plv0;
        csr_dmw1_plv3 <= csr_wmask_WB[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]  | ~csr_wmask_WB[`CSR_DMW_PLV3] & csr_dmw0_plv3;
        csr_dmw1_mat  <= csr_wmask_WB[`CSR_DMW_MAT]  & csr_wvalue[`CSR_DMW_MAT]  | ~csr_wmask_WB[`CSR_DMW_MAT]  & csr_dmw0_mat;
        csr_dmw1_pseg <= csr_wmask_WB[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]  | ~csr_wmask_WB[`CSR_DMW_PSEG] & csr_dmw0_pseg;
        csr_dmw1_vseg <= csr_wmask_WB[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]  | ~csr_wmask_WB[`CSR_DMW_VSEG] & csr_dmw0_vseg;
    end
end

//读取CSR寄存器,由于我们这次实验对于一些域的功能没有使用，所以直接赋0，我在上面定义的寄存器值可供后面拓展使用
assign csr_crmd_rvalue = {csr_crmd_rem,csr_crmd_datm,csr_crmd_datf,csr_crmd_pg,csr_crmd_da,csr_crmd_ie,csr_crmd_plv};
assign csr_prmd_rvalue = {29'b0,csr_prmd_pie,csr_prmd_pplv};
assign csr_estat_rvalue = {21'b0,1'b0,csr_estat_esubcode,csr_estat_ecode,3'b0,csr_estat_is};
assign csr_tcfg_rvalue = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
assign csr_tlbidx_rvalue = {csr_tlbidx_ne, 1'b0, csr_tlbidx_ps, 20'b0, csr_tlbidx_index};
assign csr_tlbehi_rvalue = {csr_tlbehi_vppn, 13'b0};
assign csr_tlbelo0_rvalue = {csr_tlbelo0_ppn,1'b0,csr_tlbelo0_g,csr_tlbelo0_mat,csr_tlbelo0_plv,csr_tlbelo0_d,csr_tlbelo0_v};
assign csr_tlbelo1_rvalue = {csr_tlbelo1_ppn,1'b0,csr_tlbelo1_g,csr_tlbelo1_mat,csr_tlbelo1_plv,csr_tlbelo1_d,csr_tlbelo1_v};
assign csr_asid_rvalue = {8'b0,8'd10,6'b0,csr_asid_asid};
assign csr_tlbrentry_rvalue = {csr_tlbrentry_pa,6'b0};
assign csr_dmw0_rvalue = {csr_dmw0_vseg,1'b0,csr_dmw0_pseg,19'b0,csr_dmw0_mat,csr_dmw0_plv3,2'b0,csr_dmw0_plv0};
assign csr_dmw1_rvalue = {csr_dmw1_vseg,1'b0,csr_dmw1_pseg,19'b0,csr_dmw1_mat,csr_dmw1_plv3,2'b0,csr_dmw1_plv0};
assign csr_rvalue = (csr_num == 14'h0)?csr_crmd_rvalue:
                    (csr_num == 14'h1)?csr_prmd_rvalue:
                    (csr_num == 14'h4)?csr_ecfg:
                    (csr_num == 14'h5)?csr_estat:
                    (csr_num == 14'h6)?csr_era:
                    (csr_num == 14'h7)?csr_badv_vaddr:
                    (csr_num == 14'h10)?csr_tlbidx_rvalue:
                    (csr_num == 14'h11)?csr_tlbehi_rvalue:
                    (csr_num == 14'h12)?csr_tlbelo0_rvalue:
                    (csr_num == 14'h13)?csr_tlbelo1_rvalue:
                    (csr_num == 14'h18)?csr_asid_rvalue:
                    (csr_num == 14'h88)?csr_tlbrentry_rvalue:
                    (csr_num == 14'hc)?csr_eentry:
                    (csr_num == 14'h30)?csr_save0_data:
                    (csr_num == 14'h31)?csr_save1_data:
                    (csr_num == 14'h32)?csr_save2_data:
                    (csr_num == 14'h33)?csr_save3_data:
                    (csr_num == 14'h40)?csr_tid_tid:
                    (csr_num == 14'h41)?csr_tcfg_rvalue:
                    (csr_num == 14'h42)?csr_tval:
                    (csr_num == 14'h44)?csr_ticlr_clr:
                    (csr_num == 14'h180)?csr_dmw0_rvalue:
                    (csr_num == 14'h181)?csr_dmw1_rvalue:
                    32'h0;
assign ex_entry   =  csr_eentry;

//tlbfill填入数据的地址是由硬件决定的，这里采用FIFO的方式
always @(posedge clk)begin
    if(reset)begin
        tlbfill_index <= 4'b0;
    end
    else if(inst_tlbfill & valid_WB) begin
        if(tlbfill_index == 4'd15) begin
            tlbfill_index <= 4'b0;
        end
        else begin
            tlbfill_index <= tlbfill_index + 1;
        end
    end
end

//CSR寄存器输出到TLB的信号
assign we = inst_tlbwr || inst_tlbfill;
assign w_index = inst_tlbwr ? csr_tlbidx_index : tlbfill_index;
assign r_index= csr_tlbidx_index;
assign w_e = csr_estat_ecode == 6'h3f ? 1: ~csr_tlbidx_ne; 
assign w_vppn = csr_tlbehi_vppn;
assign w_ppn0 = csr_tlbelo0_ppn;
assign w_ppn1 = csr_tlbelo1_ppn;
assign w_g = csr_tlbelo0_g && csr_tlbelo1_g;
assign w_mat0 = csr_tlbelo0_mat;
assign w_mat1 = csr_tlbelo1_mat;
assign w_plv0 = csr_tlbelo0_plv;
assign w_plv1 = csr_tlbelo1_plv;
assign w_d0   = csr_tlbelo0_d;
assign w_d1   = csr_tlbelo1_d;
assign w_v0   = csr_tlbelo0_v;
assign w_v1   = csr_tlbelo1_v;
assign w_asid = csr_asid_asid;
assign w_ps    = csr_tlbidx_ps;
endmodule
