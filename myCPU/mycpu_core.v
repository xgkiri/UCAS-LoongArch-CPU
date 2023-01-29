module mycpu_core
#(parameter TLBNUM = 16)
(
           input  wire        clk,
           input  wire        resetn,
           // inst sram interface
           output wire        inst_sram_req,
           output wire        inst_sram_wr,
           output wire [3:0 ] inst_sram_wstrb,
           output wire [1:0 ] inst_sram_size,
           output wire [31:0] inst_sram_addr,
           output wire [31:0] inst_sram_wdata,
           input  wire [31:0] inst_sram_rdata,
           input  wire        inst_sram_addr_ok,
           input  wire        inst_sram_data_ok,

           // data sram interface
           output wire        data_sram_req,
           output wire        data_sram_wr,
           output wire [3:0 ] data_sram_wstrb,
           output wire [1:0 ] data_sram_size,
           output wire [31:0] data_sram_addr,
           output wire [31:0] data_sram_wdata,
           input  wire [31:0] data_sram_rdata,
           input  wire        data_sram_addr_ok,
           input  wire        data_sram_data_ok,

           // trace debug interface
           output wire [31:0] debug_wb_pc,
           output wire [ 3:0] debug_wb_rf_we,
           output wire [ 4:0] debug_wb_rf_wnum,
           output wire [31:0] debug_wb_rf_wdata
       );

//block reset
reg         reset;
always @(posedge clk) reset <= ~resetn;
//tlb 
wire [              18:0]    s0_vppn;
wire                         s0_va_bit12;
wire [               9:0]    s0_asid;
wire                         s0_found;
wire [$clog2(TLBNUM)-1:0]    s0_index;
wire [              19:0]    s0_ppn;
wire [               5:0]    s0_ps;
wire [               1:0]    s0_plv;
wire [               1:0]    s0_mat;
wire                         s0_d;
wire                         s0_v;
wire  [              18:0]   s1_vppn;
wire                         s1_va_bit12;
wire  [               9:0]   s1_asid;
wire                         s1_found;
wire [$clog2(TLBNUM)-1:0]    s1_index;
wire [              19:0]    s1_ppn;
wire [               5:0]    s1_ps;
wire [               1:0]    s1_plv;
wire [               1:0]    s1_mat;
wire                         s1_d;
wire                         s1_v;
wire  [               4:0]   invtlb_op;
wire                         inst_invtlb;
wire                         we;
wire  [$clog2(TLBNUM)-1:0]   w_index;
wire                         w_e;
wire  [               5:0]   w_ps;
wire  [              18:0]   w_vppn;
wire  [               9:0]   w_asid;
wire                         w_g;
wire  [              19:0]   w_ppn0;
wire  [               1:0]   w_plv0;
wire  [               1:0]   w_mat0;
wire                         w_d0;
wire                         w_v0;
wire  [              19:0]   w_ppn1;
wire  [               1:0]   w_plv1;
wire  [               1:0]   w_mat1;
wire                         w_d1;
wire                         w_v1;
wire  [$clog2(TLBNUM)-1:0]   r_index;
wire                         r_e;
wire [              18:0]    r_vppn;
wire [               5:0]    r_ps;
wire [               9:0]    r_asid;
wire                         r_g;
wire [              19:0]    r_ppn0;
wire [               1:0]    r_plv0;
wire [               1:0]    r_mat0;
wire                         r_d0;
wire                         r_v0;
wire [              19:0]    r_ppn1;     
wire [               1:0]    r_plv1;
wire [               1:0]    r_mat1;
wire                         r_d1;
wire                         r_v1;
wire                         inst_tlbsrch;
wire                         inst_tlbrd;
wire                         inst_tlbfill;
wire                         inst_tlbwr;
wire [              97:0]    csr_tlb_input;
wire [              97:0]    csr_tlb_output;
wire        tlbsrch_hit;
reg         tlbsrch_hit_MEM;
reg         tlbsrch_hit_WB;
wire [31:0] csr_asid_rvalue;
wire [31:0] csr_tlbehi_rvalue;
wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_dmw0_rvalue;
wire [31:0] csr_dmw1_rvalue;
wire [31:0] csr_tlbrentry_rvalue;
reg         inst_tlbsrch_EX;
reg         inst_tlbsrch_MEM;
reg         inst_tlbsrch_WB;
reg         inst_tlbrd_EX;
reg         inst_tlbrd_MEM;
reg         inst_tlbrd_WB;
reg         inst_tlbwr_EX;
reg         inst_tlbwr_MEM;
reg         inst_tlbwr_WB;
reg         inst_tlbfill_EX;
reg         inst_tlbfill_MEM;
reg         inst_tlbfill_WB;
reg         inst_invtlb_EX;
wire        tlbsrch_block;
reg         tlb_refetch;//tlbwr tlbfill tlbrd重取标记
reg         refetch_tlb_ID;
reg         refetch_tlb_EX;
reg         refetch_tlb_MEM;
reg         refetch_tlb_WB;
wire        refetch_pc_ok;
//----------------------------------------------------------
/* add new inst for exp10 */
/* author: ljw            */
// inst
reg         inst_mul_w_EX;
reg         inst_mulh_w_EX;
reg         inst_mulh_wu_EX;
reg         inst_div_w_EX;
reg         inst_mod_w_EX;
reg         inst_div_wu_EX;
reg         inst_mod_wu_EX;
/* add new inst for exp10 */
/* author: ljw            */
wire [31:0] mul_result;
wire [31:0] mulh_result;
wire [31:0] mulhu_result;
wire [63:0] unsigned_prod;
wire [63:0] signed_prod;
wire [31:0] dividend;
wire [31:0] divisor;
wire [63:0] unsigned_divider_res;
wire [63:0] signed_divider_res;

wire        unsigned_dividend_tready;
reg         unsigned_dividend_tvalid;
wire        unsigned_divisor_tready;
reg         unsigned_divisor_tvalid;
wire        unsigned_dout_tvalid;

wire        signed_dividend_tready;
reg         signed_dividend_tvalid;
wire        signed_divisor_tready;
reg         signed_divisor_tvalid;
wire        signed_dout_tvalid;

reg         last;
reg         u_last;
//pipe_valid
reg valid_IF;
reg valid_ID;
reg valid_EX;
reg valid_MEM;
reg valid_WB;

//data_valid


wire valid_pre_IF_TO_IF;

wire valid_IF_TO_ID;
wire valid_ID_TO_EX;
wire valid_EX_TO_MEM;
wire valid_MEM_TO_WB;

//ready_go


wire ready_go_pre_IF;

wire ready_go_IF;
wire ready_go_ID;
wire ready_go_EX;
wire ready_go_MEM;
wire ready_go_WB;

//allow_in
wire allow_in_IF;
wire allow_in_ID;
wire allow_in_EX;
wire allow_in_MEM;
wire allow_in_WB;


reg inst_valid;


reg need_to_drop_IF_R;
reg need_to_drop_MEM_R;
wire need_to_drop_IF;
wire need_to_drop_MEM;

//pc_related
wire [31:0] seq_pc;
wire [31:0] next_pc;
wire [31:0] final_next_pc;
reg  [31:0] next_pc_R;
wire [31:0] trans_pc;//虚实地址翻译后的取指pc
wire [31:0] trans_addr_ex;
wire        da_hit;
wire        dmw0_hit_pre_if;
wire        dmw1_hit_pre_if;
wire [31:0] dmw_addr_pre_if;
wire [31:0] tlb_addr_pre_if;
wire        dmw0_hit_ex;
wire        dmw1_hit_ex;
wire [31:0] dmw_addr_ex;
wire [31:0] tlb_addr_ex;
wire        br_taken;
wire [31:0] br_target;
reg  [31:0] inst_IF;
reg  [31:0] inst;
reg         br_taken_R;
reg         mid_handshake_inst;
//reg         mid_handshake_data;

reg  [31:0] pc_IF;
reg  [31:0] pc_ID;
reg  [31:0] pc_EX;
reg  [31:0] pc_MEM;
reg  [31:0] pc_WB;

//control_signals
wire [11:0] alu_op;
reg  [11:0] alu_op_EX;

wire        load_op;

wire        src1_is_pc;
wire        src2_is_imm;

wire        res_from_mem_ID;
reg         res_from_mem_EX;
reg         res_from_mem_MEM;

wire        dst_is_r1;

wire        gr_we_ID;
reg         gr_we_EX;
reg         gr_we_MEM;
reg         gr_we_WB;

wire        mem_we_ID;
reg         mem_we_EX;

wire        src_reg_is_rd;

wire        RAW_BLOCK;

wire        br_cancel;
wire        ex_cancel;
wire        cancel_ID;
wire        br_blocked;
wire        is_branch_inst;

//data_prepared
wire [4: 0] dest_ID;
reg  [4: 0] dest_EX;
reg  [4: 0] dest_MEM;
reg  [4: 0] dest_WB;

wire [31:0] rj_value;
reg  [31:0] rj_value_EX;
reg  [31:0] rj_value_MEM;
reg  [31:0] rj_value_WB;
wire [31:0] rkd_value_ID;
reg  [31:0] rkd_value_EX;
reg  [31:0] rkd_value_MEM;
reg  [31:0] rkd_value_WB;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

//inst_info
wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;
/* add new inst for exp13 */
/* author: ljw            */
wire [13:0] csr_num;
reg  [13:0] csr_num_EX;
reg  [13:0] csr_num_MEM;
reg  [13:0] csr_num_WB;
wire [14:0] code;//syscall

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

//inst_identify
wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;

wire        inst_ld_w;


reg         is_load_inst_EX;
reg         is_store_inst_EX;
reg         is_load_inst_MEM;
reg         is_store_inst_MEM;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;

/* add new inst for exp10 */
/* author: hyx            */
wire        inst_slti;
wire        inst_sltui;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sll_w;
wire        inst_srl_w;
wire        inst_sra_w;
wire        inst_pcaddu12i;

/* add new inst for exp10 */
/* author: ljw            */

wire        inst_mul_w;
wire        inst_mulh_w;
wire        inst_mulh_wu;
wire        inst_div_w;
wire        inst_mod_w;
wire        inst_div_wu;
wire        inst_mod_wu;

wire        inst_mul_w_IN_EX;
wire        inst_mulh_w_IN_EX;
wire        inst_mulh_wu_IN_EX;
wire        inst_div_w_IN_EX;
wire        inst_mod_w_IN_EX;
wire        inst_div_wu_IN_EX;
wire        inst_mod_wu_IN_EX;
//new instruction branch and mem
//author:lmy
wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;
wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;
wire        inst_st_b;
wire        inst_st_h;
reg         inst_st_b_EX;
reg         inst_st_h_EX;
reg         inst_st_w_EX;
reg         inst_ld_b_EX;
reg         inst_ld_bu_EX;
reg         inst_ld_h_EX;
reg         inst_ld_hu_EX;
reg         inst_ld_w_EX;
reg         inst_ld_b_MEM;
reg         inst_ld_bu_MEM;
reg         inst_ld_h_MEM;
reg         inst_ld_hu_MEM;
reg         inst_ld_w_MEM;

/* add new inst for exp12 */
/* author: ljw            */

wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_ertn;
wire        inst_syscall;
wire        inst_break;
reg         inst_csrrd_EX;
reg         inst_csrwr_EX;
reg         inst_csrxchg_EX;
reg         inst_ertn_EX;
reg         inst_syscall_EX;
reg         inst_break_EX;
reg         inst_csrrd_MEM;
reg         inst_csrwr_MEM;
reg         inst_csrxchg_MEM;
reg         inst_ertn_MEM;
reg         inst_syscall_MEM;
reg         inst_break_MEM;
reg         inst_csrrd_WB;
reg         inst_csrwr_WB;
reg         inst_csrxchg_WB;
reg         inst_ertn_WB;
reg         inst_syscall_WB;
reg         inst_break_WB;

/* add new exception signal */
/* author hyx               */
wire        inst_addr_wrong;//in pre_IF
reg         inst_addr_wrong_IF;
reg         inst_addr_wrong_ID;
reg         inst_addr_wrong_EX;
reg         inst_addr_wrong_MEM;
reg         inst_addr_wrong_WB;

wire        mem_addr_wrong;//in EX
reg         mem_addr_wrong_MEM;
reg         mem_addr_wrong_WB;

wire        invalid_inst;//in ID
reg         invalid_inst_EX;
reg         invalid_inst_MEM;
reg         invalid_inst_WB;

/*timer int*/
wire        inst_rdcntvh;
wire        inst_rdcntvl;
wire        inst_rdcntid;
reg         inst_rdcntid_EX;
reg         inst_rdcntvh_EX;
reg         inst_rdcntvl_EX;
wire [31:0] count_data;
reg  [31:0] count_data_MEM;
wire        read_count_data_h_EX;
wire        read_count_data_EX;
reg         read_count_data_MEM;

/*int check*/
wire [11:0] csr_estat_is;
wire [11:0] csr_ecfg_lie;
wire        csr_crmd_ie;
wire [ 1:0] csr_crmd_plv;

/*tlb exception*/
wire        is_mapping_vaddr_if;
wire        is_mapping_vaddr_ex;

//TLB重填、页特权等级不合规都可能在取指或访存时发生

//tlb重填
wire        tlb_refill_pre_IF;//in pre_IF
reg         tlb_refill_IF;
reg         tlb_refill_ID;
wire        tlb_refill_EX;//in EX
reg         tlb_refill_EX_R;
reg         tlb_refill_MEM;
reg         tlb_refill_WB;
//load页无效
wire        pte_invalid_load;//in EX
reg         pte_invalid_load_MEM;
reg         pte_invalid_load_WB;
//store页无效
wire        pte_invalid_store;//in EX
reg         pte_invalid_store_MEM;
reg         pte_invalid_store_WB;
//取指页无效
wire        pte_invalid_fetch;//in pre_IF
reg         pte_invalid_fetch_IF;
reg         pte_invalid_fetch_ID;
reg         pte_invalid_fetch_EX;
reg         pte_invalid_fetch_MEM;
reg         pte_invalid_fetch_WB;
//特权等级不合规
wire        pte_plv_invalid;//in EX
reg         pte_plv_invalid_MEM;
reg         pte_plv_invalid_WB;
//页修改例外
wire        pte_m_e;//in EX
reg         pte_m_e_MEM;
reg         pte_m_e_WB;  

//访存指令地址错例外
wire        adem;
wire        adem_detected;//in EX
reg         adem_detected_MEM;
reg         adem_detected_WB;

//取值地址错例外的另一种情况
wire        adef;

//control_signals_data
wire        need_ui5;
wire        need_si12;
wire        need_si12_u;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;
//bge blt judge adder
wire [31:0] adder_result;
wire        adder_cout;
//reg_file
wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

//alu
wire [31:0] alu_src1_ID;
reg  [31:0] alu_src1_EX;
wire [31:0] alu_src2_ID;
reg  [31:0] alu_src2_EX;
wire [31:0] alu_result_EX_alu ;
reg  [31:0] alu_result_MEM;
wire [31:0] alu_result_EX;

//ld_data_extend
wire [31:0] ld_b_data;
wire [31:0] ld_bu_data;
wire [31:0] ld_h_data;
wire [31:0] ld_hu_data;
wire [1:0] addr_low_MEM;
wire [1:0] addr_low_EX;
//rf_wdata_related
wire [31:0] mem_result;
wire [31:0] final_result_MEM;
reg  [31:0] final_result_WB;
reg  [31:0] data_sram_rdata_R;
reg         data_sram_rdata_valid;
wire [31:0] final_data_sram_rdata;
//forward pass
wire [31:0] data_from_EX;
wire [31:0] data_from_MEM;
wire [31:0] data_from_WB;

wire [31:0 ] src1_after_forward;
wire [31:0 ] src2_after_forward;


wire         ex_pre_IF_occur; 
reg          ex_IF;  
wire         ex_IF_occur;
reg          ex_ID;     
wire         ex_ID_occur;     
reg          ex_EX;     
wire         ex_EX_occur;    
reg          ex_MEM;
wire         ex_MEM_occur;
reg          ex_WB;      
wire         ex_WB_occur;
reg          ex_WB_occur_R;
wire         ex_invtlb;
reg          inst_ex_valid;



wire [5:0] has_int;

//vaddr
wire [31:0]vaddr;//in EX
reg  [31:0]vaddr_MEM;
reg  [31:0]vaddr_WB;


reg ertn_doing;
reg ertn_done;
reg ertn_finish;


wire [31:0]ex_entry;
wire [31:0]ex_tlbentry; // TLB相关异常需要跳转到的异常处理入口
wire       is_csr_EX;
reg        is_csr_MEM;
reg        is_csr_WB;
wire       is_csr_WB_block;
wire       ertn_flush;
wire       csr_re;
wire       csr_we;
wire [31:0]csr_wvalue;
wire [31:0]csr_wmask_WB;
wire [31:0]csr_rvalue;

wire  [5:0] ecode_WB;
wire  [8:0] esubcode_WB;
reg  WB_TO_IF_bus;
reg  WB_TO_ID_bus;
reg  WB_TO_EX_bus;
reg  WB_TO_MEM_bus;
reg  MEM_TO_EX_bus;
wire RAW_BLOCK_EX;
wire RAW_BLOCK_MEM;
/*
*MMU相关的冲突取消标记
*/
reg    refetch;
reg    ex_MMU;
reg    ex_MMU_IF;
reg    ex_MMU_ID;
reg    ex_MMU_EX;
reg    ex_MMU_MEM;
reg    ex_MMU_WB;
wire    ex_pc_ok;
wire    crmd_change = csr_num == 14'h0;
wire    DMW0_change = csr_num == 14'h180;
wire    DMW1_change = csr_num == 14'h181;
wire    asid_change = csr_num == 14'h18;

assign ex_tlbentry = csr_tlbrentry_rvalue;
//assign ex_MMU = (crmd_change || DMW0_change || DMW1_change || asid_change) && (inst_csrwr || inst_csrxchg) && valid_ID;
always @(posedge clk)begin
    if((crmd_change || DMW0_change || DMW1_change || asid_change) && (inst_csrwr || inst_csrxchg) && valid_ID)begin
        ex_MMU <= 1'b1;    
    end
    else if(ex_MMU_ID)begin
        ex_MMU <= 1'b0;
    end
end
always @(posedge clk)begin
    if(reset)begin
        ex_MMU_ID <= 0;
    end
    else if(ex_MMU && valid_IF_TO_ID && allow_in_ID)begin
        ex_MMU_ID <= 1;
    end
end
always@(posedge clk)begin
    if(ex_MMU_WB)begin
        ex_MMU_ID <= 0;
        ex_MMU_EX <= 0;
        ex_MMU_MEM <= 0;
        //ex_MMU_WB <= 0;
    end
end
//assign ex_pc_ok = ex_MMU_WB && inst_sram_req;
/*
*tlb相关的阻塞和重取,与上面的MMU ex的方法相同，若上面有错误，记得同样更改这一块位置
*/
assign tlbsrch_block = ((inst_csrwr_MEM||inst_csrxchg_MEM)&&(csr_num_MEM==14'h18||csr_num_MEM==14'h11) || inst_tlbrd_MEM)&&valid_MEM;
//assign tlb_refetch = (inst_tlbfill || inst_tlbwr || inst_tlbrd || inst_invtlb)&&valid_ID;

always @(posedge clk)begin
    if((inst_tlbfill || inst_tlbwr || inst_tlbrd || inst_invtlb)&&valid_ID)
        tlb_refetch <= 1'b1;
    else if(refetch_tlb_ID)begin
        tlb_refetch <= 1'b0;
    end
end
always @(posedge clk)begin
    if(reset)begin
        refetch_tlb_ID <= 0;
    end
    else if(tlb_refetch && valid_IF_TO_ID && allow_in_ID)begin
        refetch_tlb_ID <= 1;
    end
    
end
always@(posedge clk)begin
    if(refetch_tlb_WB)begin
        refetch_tlb_ID <= 0;
        refetch_tlb_EX <= 0;
        refetch_tlb_MEM <= 0;
        //refetch_tlb_WB <= 0;
    end
end
//assign refetch_pc_ok = refetch_tlb_WB && inst_sram_req;
/*                   exp12 */
/* author: ljw            */

assign read_count_data_EX = inst_rdcntvh_EX | inst_rdcntvh_EX;
assign read_count_data_h_EX = inst_rdcntvh_EX;

assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) != 12'b0) && (csr_crmd_ie == 1'b1);

assign data_from_EX  = alu_result_EX;

assign data_from_MEM = final_result_MEM;

assign data_from_WB  = is_csr_WB ? csr_rvalue : final_result_WB;

assign src1_after_forward = rf_raddr1 == dest_EX  & dest_EX  != 5'b0 & gr_we_EX  & valid_EX        ? data_from_EX :
                            rf_raddr1 == dest_MEM & dest_MEM != 5'b0 & gr_we_MEM & valid_MEM_TO_WB ? data_from_MEM:
                            rf_raddr1 == dest_WB  & dest_WB  != 5'b0 & gr_we_WB  & valid_WB        ? data_from_WB :
                                                                                                     rj_value;

assign src2_after_forward = rf_raddr2 == dest_EX  & dest_EX  != 5'b0 & gr_we_EX  & valid_EX        ? data_from_EX :
                            rf_raddr2 == dest_MEM & dest_MEM != 5'b0 & gr_we_MEM & valid_MEM_TO_WB ? data_from_MEM:
                            rf_raddr2 == dest_WB  & dest_WB  != 5'b0 & gr_we_WB  & valid_WB        ? data_from_WB :
                                                                                                     rkd_value_ID;        


//ex
assign ex_invtlb =  inst_invtlb && !(invtlb_op == 5'h0 || invtlb_op == 5'h1 || invtlb_op == 5'h2 || invtlb_op == 5'h3 || invtlb_op == 5'h4 || invtlb_op == 5'h5 || invtlb_op == 5'h6);

assign ex_pre_IF_occur = inst_addr_wrong || tlb_refill_pre_IF || pte_invalid_fetch;
assign ex_IF_occur = ex_IF;
assign ex_ID_occur = ex_ID || inst_syscall || inst_break || invalid_inst || has_int; 
assign ex_EX_occur = ex_EX || mem_addr_wrong || pte_invalid_load || pte_invalid_store || pte_plv_invalid || pte_m_e || tlb_refill_EX || adem_detected;
assign ex_MEM_occur= ex_MEM;
assign ex_WB_occur = ex_WB;                                    
//--------------------------------------------------------------------
//update pc
always @(posedge clk)begin
    if(reset)
        refetch <= 1'b0;
    else if(ex_MMU_WB||refetch_tlb_WB)begin
        refetch <= 1'b1;
    end
    else if(inst_sram_addr_ok)begin
        refetch <= 1'b0;
    end
end
assign seq_pc        =  pc_IF + 32'h4;
assign next_pc       =  refetch ?    pc_WB          :
                        ex_WB_occur && tlb_refill_WB && valid_WB? ex_tlbentry :
                        ex_WB_occur  && valid_WB? ex_entry       : 
                        inst_ertn_WB && valid_WB? csr_rvalue     :              
                        br_taken ?                br_target      : 
                                                  seq_pc;
assign final_next_pc =  ex_WB_occur && valid_WB       ?   next_pc  :
                        (br_taken_R || ex_WB_occur_R) ?   next_pc_R:
                                                          next_pc  ;
assign da_hit = csr_crmd_rvalue[3]==1 && csr_crmd_rvalue[4]==0;//直接地址翻译
/*间接地址翻译*/
assign dmw0_hit_pre_if = (csr_crmd_rvalue[1:0] == 2'b00 && csr_dmw0_rvalue[0]   ||
                   csr_crmd_rvalue[1:0] == 2'b11 && csr_dmw0_rvalue[3] ) && (final_next_pc[31:29] == csr_dmw0_rvalue[31:29]); 
assign dmw1_hit_pre_if = (csr_crmd_rvalue[1:0] == 2'b00 && csr_dmw1_rvalue[0]   ||
                   csr_crmd_rvalue[1:0] == 2'b11 && csr_dmw1_rvalue[3] ) && (final_next_pc[31:29] == csr_dmw1_rvalue[31:29]); 
assign dmw_addr_pre_if = {32{dmw0_hit_pre_if}} & {csr_dmw0_rvalue[27:25], final_next_pc[28:0]} |
                  {32{dmw1_hit_pre_if}} & {csr_dmw1_rvalue[27:25], final_next_pc[28:0]};
assign s0_vppn = final_next_pc[31:13];
assign s0_va_bit12 = final_next_pc[12];
assign s0_asid = csr_asid_rvalue[9:0];
//tlb地址查找
assign tlb_addr_pre_if = s0_ps == 6'd12 ? {s0_ppn[19:0],final_next_pc[11:0]} :
                                   {s0_ppn[19:10],final_next_pc[21:0]};
assign trans_pc =   da_hit ?             final_next_pc  :
                    dmw0_hit_pre_if||dmw1_hit_pre_if ? dmw_addr_pre_if       :
                                         tlb_addr_pre_if         ;

assign adef = is_mapping_vaddr_if && final_next_pc[31];
assign inst_addr_wrong = !(final_next_pc[1:0] == 2'b00) || adef;

always @(posedge clk)begin
    if(reset)begin
        mid_handshake_inst <= 0;
    end
    else if (inst_sram_data_ok)begin
        mid_handshake_inst <= 0;
    end
    else if (inst_sram_req && inst_sram_addr_ok)begin
        mid_handshake_inst <= 1;
    end
end
/*
always @(posedge clk)begin
    if(reset)begin
        mid_handshake_data <= 0;
    end
    else if (data_sram_data_ok)begin
        mid_handshake_data <= 0;
    end
    else if (data_sram_req && data_sram_addr_ok)begin
        mid_handshake_data <= 1;
    end
end
*/
always @(posedge clk) begin
    if(reset)begin
        br_taken_R <= 1'b0;
    end
    else if(br_taken_R && inst_sram_req && inst_sram_addr_ok && allow_in_IF)begin
        br_taken_R <= 1'b0;
    end
    else if(~(inst_sram_req && inst_sram_addr_ok) && br_taken)begin
        br_taken_R <= 1'b1;
    end
end

always @(posedge clk)begin
    if(reset)begin
        ex_WB_occur_R <= 1'b0;
    end
    else if(ex_WB_occur_R && inst_sram_req && inst_sram_addr_ok && allow_in_IF)begin
        ex_WB_occur_R <= 1'b0;
    end
    else if(~(inst_sram_req && inst_sram_addr_ok) && ex_cancel)begin
        ex_WB_occur_R <= 1'b1;
    end
end

//pre_IF级的异常
always @(posedge clk) begin
    if (ex_pre_IF_occur) begin
        ex_IF <= 1'b1;
    end
    else begin
        ex_IF <= 1'b0;
    end
end

always @(posedge clk) begin
    if (inst_addr_wrong) begin
        inst_addr_wrong_IF <= 1'b1;
    end
    else begin
        inst_addr_wrong_IF <= 1'b0;
    end
end

always @(posedge clk) begin
    if (pte_invalid_fetch) begin
        pte_invalid_fetch_IF <= 1'b1;
    end
    else begin
        pte_invalid_fetch_IF <= 1'b0;
    end
end

always @(posedge clk) begin
    if (tlb_refill_pre_IF) begin
        tlb_refill_IF <= 1'b1;
    end
    else begin
        tlb_refill_IF <= 1'b0;
    end
end
//

always @(posedge clk) begin
    if(reset)begin
      next_pc_R <= 32'b0;
    end
    else if(br_taken || ex_cancel)begin //锟斤拷要br_stall
      next_pc_R <= next_pc;
    end
end

always @(posedge clk) begin
    if (reset) begin
        pc_IF <= 32'h1BFFFFFC;
    end
    
    else if (allow_in_IF && ready_go_pre_IF) begin
        pc_IF <= final_next_pc;
    end
end

//pipe_valid
always @(posedge clk) begin
    if (reset) begin
        valid_IF <= 0;
    end
    else if (allow_in_IF) begin
        valid_IF <= valid_pre_IF_TO_IF;
    end
    else if(ex_cancel || ex_MMU_WB || refetch_tlb_WB) begin
        valid_IF <= 0;
    end
    
end


assign br_cancel = br_taken && ready_go_ID;
assign ex_cancel = ex_WB_occur || ertn_flush;
assign cancel_ID = br_cancel || ex_cancel;

always @(posedge clk) begin
    if (reset) begin
        valid_ID <= 0;
    end
    else if (cancel_ID || ex_MMU_WB || refetch_tlb_WB) begin
        valid_ID <= 0;
    end
    else if (allow_in_ID) begin
        valid_ID <= valid_IF_TO_ID;
    end
end

always @(posedge clk) begin
    if (reset) begin
        valid_EX <= 0;
    end
    else if(ex_cancel || ex_MMU_WB || refetch_tlb_WB)begin
        valid_EX <= 0;
    end
    else if (allow_in_EX) begin
        valid_EX <= valid_ID_TO_EX;
    end
end

always @(posedge clk) begin
    if (reset) begin
        valid_MEM <= 0;
    end
    else if(ex_cancel || ex_MMU_WB || refetch_tlb_WB)begin
        valid_MEM <= 0;
    end
    else if (allow_in_MEM) begin
        valid_MEM <= valid_EX_TO_MEM;
    end
end

always @(posedge clk) begin
    if (reset) begin
        valid_WB <= 0;
    end
    else if(ex_cancel || ex_MMU_WB || refetch_tlb_WB)begin
        valid_WB <= 0;
    end
    else if (allow_in_WB) begin
        valid_WB <= valid_MEM_TO_WB;
    end
end

//ready_go
assign ready_go_pre_IF = inst_sram_req && inst_sram_addr_ok || pte_invalid_fetch || tlb_refill_pre_IF;

assign ready_go_IF  = (inst_sram_data_ok || inst_valid) || pte_invalid_fetch_IF || tlb_refill_IF;

assign ready_go_ID  = (RAW_BLOCK || (is_csr_WB_block)) ? 1'b0:
                      1'b1;

assign ready_go_EX  =   tlbsrch_block ? 1'b0                                          :
                        (inst_div_w_EX   || inst_mod_w_EX   ) ? signed_dout_tvalid    : 
                        (inst_div_wu_EX  || inst_mod_wu_EX  ) ? unsigned_dout_tvalid  : 
                        (is_load_inst_EX || is_store_inst_EX) ? (data_sram_req && data_sram_addr_ok ||
                        pte_invalid_load || pte_invalid_store || pte_m_e || pte_plv_invalid) : 
                        1'b1; 

assign ready_go_MEM = (is_load_inst_MEM || is_store_inst_MEM) ? ((data_sram_data_ok || data_sram_rdata_valid) && ~need_to_drop_MEM ||
                        pte_invalid_load || pte_invalid_store || pte_m_e || pte_plv_invalid) : 1'b1;

assign ready_go_WB  = 1;

assign RAW_BLOCK = (valid_EX && RAW_BLOCK_EX) || (valid_MEM && RAW_BLOCK_MEM);
assign RAW_BLOCK_EX  = (dest_EX  == rf_raddr1 | dest_EX  == rf_raddr2) & dest_EX   != 5'b0 & (is_load_inst_EX | is_csr_EX) & valid_ID;
assign RAW_BLOCK_MEM = (dest_MEM == rf_raddr1 | dest_MEM == rf_raddr2) & dest_MEM  != 5'b0 & (is_csr_MEM || is_load_inst_MEM) & valid_ID;

//allow_in
assign allow_in_IF  = !valid_IF  || ready_go_IF  && allow_in_ID;

assign allow_in_ID  = (!valid_ID  || ready_go_ID  && allow_in_EX  || ertn_flush || ex_WB_occur) && 
                      ~(RAW_BLOCK === 1); 
assign allow_in_EX  = !valid_EX  || ready_go_EX  && allow_in_MEM;
assign allow_in_MEM = !valid_MEM || ready_go_MEM && allow_in_WB;
assign allow_in_WB  = !valid_WB  || ready_go_WB;




//data_valid
assign valid_pre_IF_TO_IF = ready_go_pre_IF;
assign valid_IF_TO_ID  = valid_IF  && ready_go_IF && ~br_taken;
assign valid_ID_TO_EX  = valid_ID  && ready_go_ID;
assign valid_EX_TO_MEM = valid_EX  && ready_go_EX;
assign valid_MEM_TO_WB = valid_MEM && ready_go_MEM;


always @(posedge clk) begin
    if (reset) begin
        inst_valid <= 0;
    end
   
    else if (ready_go_IF && allow_in_ID || ex_cancel) begin 
        inst_valid <= 0;
    end
   
    else if (inst_sram_data_ok && ~allow_in_ID) begin
        inst_valid <= 1;
    end
end


assign need_to_drop_IF  = need_to_drop_IF_R;
assign need_to_drop_MEM = need_to_drop_MEM_R;
always @(posedge clk) begin
    if (reset) begin
        need_to_drop_IF_R <= 0;
    end
    
    else if (inst_sram_data_ok)begin
        need_to_drop_IF_R <= 0;
    end
    /*
    else if(ex_cancel && (~allow_in_IF && ~ready_go_IF || valid_pre_IF_to_IF)) begin
        need_to_drop_IF_R <= 1;
    end
    */
    else if(ex_cancel && (inst_sram_req && inst_sram_addr_ok)) begin
        need_to_drop_IF_R <= 1;
    end
end

always @(posedge clk) begin
    if (reset) begin
        inst_ex_valid <= 1;
    end
    else if (need_to_drop_IF) begin
        inst_ex_valid <= 0;
    end
    else if (!need_to_drop_IF && inst_sram_data_ok) begin
        inst_ex_valid <= 1;
    end
end

always @(posedge clk) begin
    if (reset) begin
        need_to_drop_MEM_R <= 0;
    end
    else if(data_sram_data_ok) begin
        need_to_drop_MEM_R <= 0;
    end
    else if(ex_cancel && (is_load_inst_EX || is_store_inst_EX) && (valid_EX_TO_MEM || ~allow_in_MEM && ~ready_go_MEM)) begin
        need_to_drop_MEM_R <= 1;
    end
    
end


assign is_branch_inst = inst_beq || inst_bne || inst_bl || inst_b || inst_blt || inst_bge || inst_bltu || inst_bgeu || inst_jirl;
assign br_blocked = is_branch_inst && ~ready_go_ID;


//-------------------------------------------------------------------------
/*

IF:     valid, pc,                                                         inst

ID:     valid, pc, gr_we, dest, res_from_mem, src1, src2, alu_op, mem_we, (inst, inst_id, imm_use_id, rdata), rkd_value rj_value csr_num

EX:     valid, pc, gr_we, dest, res_from_mem, src1, src2, alu_op, mem_we, alu_result,                         rkd_value rj_value csr_num

MEM:    valid, pc, gr_we, dest, res_from_mem,                             alu_result, final_result            rkd_value rj_value csr_num

WB:     valid, pc, gr_we, dest,                                                       final_result            rkd_value rj_value csr_num
                  (rf_we) (rf_waddr)                                                   (rf_wdata)

*/

//pre_IF_TO_IF
always @(posedge clk) begin
    if (ready_go_IF && ~allow_in_ID && inst_sram_data_ok && !need_to_drop_IF) begin
        inst_IF <= inst_sram_rdata;
    end
end

//IF_TO_ID
always @(posedge clk) begin
    if (valid_IF_TO_ID && allow_in_ID) begin
        pc_ID <= pc_IF;
        ex_ID <= ex_IF_occur & ~ex_WB_occur;
        inst_addr_wrong_ID <= inst_addr_wrong_IF & ~ex_WB_occur;
        tlb_refill_ID <= tlb_refill_IF & ~ex_WB_occur;
        pte_invalid_fetch_ID <= pte_invalid_fetch_IF & ~ex_WB_occur;
    end
    
    else if(ex_WB_occur || ex_MMU_WB || refetch_tlb_WB)begin
        ex_ID <= 0;
        inst_addr_wrong_ID <= 0;
        tlb_refill_ID <= 0;
        pte_invalid_fetch_ID <= 0;
    end
end

always @(posedge clk) begin
    if (valid_IF_TO_ID && allow_in_ID && !need_to_drop_IF) begin
        inst  <= inst_valid? inst_IF : inst_sram_rdata;
    end
end

//ID_TO_EX
always @(posedge clk) begin
    if (valid_ID_TO_EX && allow_in_EX) begin
        pc_EX           <= pc_ID;
        gr_we_EX        <= gr_we_ID;
        dest_EX         <= dest_ID;
        res_from_mem_EX <= res_from_mem_ID;
        alu_src1_EX     <= alu_src1_ID;
        alu_src2_EX     <= alu_src2_ID;
        alu_op_EX       <= alu_op;
        mem_we_EX       <= mem_we_ID;
        rkd_value_EX    <= src2_after_forward;
        rj_value_EX     <= src1_after_forward;
        is_load_inst_EX <= (inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu) & ~ex_WB_occur;
        is_store_inst_EX<= (inst_st_b | inst_st_h | inst_st_w                          ) & ~ex_WB_occur;
        inst_mul_w_EX   <= inst_mul_w & ~ex_WB_occur;
        inst_mulh_w_EX  <= inst_mulh_w & ~ex_WB_occur;
        inst_mulh_wu_EX <= inst_mulh_wu & ~ex_WB_occur;
        inst_div_w_EX   <= inst_div_w & ~ex_WB_occur;
        inst_mod_w_EX   <= inst_mod_w & ~ex_WB_occur;
        inst_div_wu_EX  <= inst_div_wu & ~ex_WB_occur;
        inst_mod_wu_EX  <= inst_mod_wu & ~ex_WB_occur;
        inst_ld_b_EX   <= inst_ld_b & ~ex_WB_occur;
        inst_ld_bu_EX  <= inst_ld_bu & ~ex_WB_occur;
        inst_ld_h_EX   <= inst_ld_h & ~ex_WB_occur;
        inst_ld_hu_EX  <= inst_ld_hu & ~ex_WB_occur;
        inst_ld_w_EX   <= inst_ld_w & ~ex_WB_occur;
        inst_st_b_EX   <= inst_st_b & ~ex_WB_occur;
        inst_st_h_EX   <= inst_st_h & ~ex_WB_occur;
        inst_st_w_EX   <= inst_st_w & ~ex_WB_occur;
        inst_csrrd_EX   <= inst_csrrd & ~ex_WB_occur;
        inst_csrwr_EX   <= inst_csrwr & ~ex_WB_occur;
        inst_csrxchg_EX <= inst_csrxchg & ~ex_WB_occur;
        inst_ertn_EX    <= inst_ertn & ~ex_WB_occur;
        inst_syscall_EX <= inst_syscall & ~ex_WB_occur;
        inst_break_EX   <= inst_break & ~ex_WB_occur;
        ex_EX           <= ex_ID_occur & ~ex_WB_occur;
        csr_num_EX      <= csr_num;
        inst_addr_wrong_EX <= inst_addr_wrong_ID & ~ex_WB_occur;
        invalid_inst_EX <= invalid_inst & ~ex_WB_occur;
        inst_rdcntid_EX <= inst_rdcntid & ~ex_WB_occur;
        inst_rdcntvh_EX <= inst_rdcntvh & ~ex_WB_occur;
        inst_rdcntvl_EX <= inst_rdcntvl & ~ex_WB_occur;
        ex_MMU_EX       <= ex_MMU_ID;
        inst_tlbrd_EX   <= inst_tlbrd;
        inst_tlbsrch_EX   <= inst_tlbsrch;
        inst_tlbfill_EX <= inst_tlbfill;
        inst_tlbwr_EX   <= inst_tlbwr;
        refetch_tlb_EX  <= refetch_tlb_ID;
        inst_invtlb_EX  <= inst_invtlb;
        tlb_refill_EX_R    <= tlb_refill_ID & ~ex_WB_occur;
        pte_invalid_fetch_EX <= pte_invalid_fetch_ID & ~ex_WB_occur;
    end
    else if(ex_WB_occur || ex_MMU_WB || refetch_tlb_WB)begin
        is_load_inst_EX <= 0;
        is_store_inst_EX<= 0;
        inst_mul_w_EX   <= 0;
        inst_mulh_w_EX  <= 0;
        inst_mulh_wu_EX <= 0;
        inst_div_w_EX   <= 0;
        inst_mod_w_EX   <= 0;
        inst_div_wu_EX  <= 0;
        inst_mod_wu_EX  <= 0;
        inst_ld_b_EX   <= 0;
        inst_ld_bu_EX  <= 0;
        inst_ld_h_EX   <= 0;
        inst_ld_hu_EX  <= 0;
        inst_ld_w_EX   <= 0;
        inst_st_b_EX   <= 0;
        inst_st_h_EX   <= 0;
        inst_st_w_EX   <= 0;
        inst_csrrd_EX   <= 0;
        inst_csrwr_EX   <= 0;
        inst_csrxchg_EX <= 0;
        inst_ertn_EX    <= 0;
        inst_syscall_EX <= 0;
        inst_break_EX   <= 0;
        inst_addr_wrong_EX <= 0;
        invalid_inst_EX <= 0;
        inst_rdcntid_EX <= 0;
        inst_rdcntvh_EX <= 0;
        inst_rdcntvl_EX <= 0;
        ex_EX <= 0;
        inst_tlbrd_EX   <= 0;
        inst_tlbrd_EX   <= 0;
        inst_tlbfill_EX <= 0;
        inst_tlbwr_EX   <= 0;
        tlb_refill_EX_R <= 0;
        pte_invalid_fetch_EX <= 0;
    end
end



//EX_TO_MEM
always @(posedge clk) begin
    if (valid_EX_TO_MEM && allow_in_MEM) begin
        pc_MEM           <= pc_EX;
        gr_we_MEM        <= gr_we_EX;
        dest_MEM         <= dest_EX;
        res_from_mem_MEM <= res_from_mem_EX;
        alu_result_MEM   <= alu_result_EX;
        rkd_value_MEM    <= rkd_value_EX;
        rj_value_MEM     <= rj_value_EX;
        inst_ld_b_MEM    <= inst_ld_b_EX & ~ex_WB_occur;
        inst_ld_bu_MEM   <= inst_ld_bu_EX & ~ex_WB_occur;
        inst_ld_h_MEM    <= inst_ld_h_EX & ~ex_WB_occur;
        inst_ld_hu_MEM   <= inst_ld_hu_EX & ~ex_WB_occur;
        inst_ld_w_MEM    <= inst_ld_w_EX & ~ex_WB_occur;
        inst_csrrd_MEM   <= inst_csrrd_EX & ~ex_WB_occur;
        inst_csrwr_MEM   <= inst_csrwr_EX & ~ex_WB_occur;
        inst_csrxchg_MEM <= inst_csrxchg_EX & ~ex_WB_occur;
        inst_ertn_MEM    <= inst_ertn_EX & ~ex_WB_occur;
        inst_syscall_MEM <= inst_syscall_EX & ~ex_WB_occur;
        inst_break_MEM   <= inst_break_EX & ~ex_WB_occur;
        ex_MEM           <= ex_EX_occur & ~ex_WB_occur;
        csr_num_MEM      <= csr_num_EX;
        is_csr_MEM       <= is_csr_EX;
        inst_addr_wrong_MEM <= inst_addr_wrong_EX & ~ex_WB_occur;
        mem_addr_wrong_MEM  <= mem_addr_wrong;
        invalid_inst_MEM <= invalid_inst_EX & ~ex_WB_occur;
        vaddr_MEM        <= vaddr;
        count_data_MEM   <= count_data & ~ex_WB_occur; 
        read_count_data_MEM <= read_count_data_EX & ~ex_WB_occur;
        is_store_inst_MEM   <= is_store_inst_EX;
        is_load_inst_MEM    <= is_load_inst_EX;
        ex_MMU_MEM       <= ex_MMU_EX;
        inst_tlbrd_MEM      <= inst_tlbrd_EX;
        tlbsrch_hit_MEM     <= tlbsrch_hit;
        inst_tlbsrch_MEM   <= inst_tlbsrch_EX;
        inst_tlbfill_MEM <= inst_tlbfill_EX;
        inst_tlbwr_MEM   <= inst_tlbwr_EX;
        refetch_tlb_MEM  <= refetch_tlb_EX; 
        tlb_refill_MEM   <= (tlb_refill_EX_R || tlb_refill_EX) & ~ex_WB_occur;
        pte_invalid_load_MEM <= pte_invalid_load & ~ex_WB_occur;
        pte_invalid_store_MEM <= pte_invalid_store & ~ex_WB_occur;
        pte_invalid_fetch_MEM <= pte_invalid_fetch_EX & ~ex_WB_occur;
        pte_plv_invalid_MEM <= pte_plv_invalid & ~ex_WB_occur;
        pte_m_e_MEM <= pte_m_e & ~ex_WB_occur;
        adem_detected_MEM <= adem_detected & ~ex_WB_occur;
    end
    else if(ex_WB_occur || ex_MMU_WB || refetch_tlb_WB)begin
        inst_ld_b_MEM    <= 0;
        inst_ld_bu_MEM   <= 0;
        inst_ld_h_MEM    <= 0;
        inst_ld_hu_MEM   <= 0;
        inst_ld_w_MEM    <= 0;
        inst_csrrd_MEM   <= 0;
        inst_csrwr_MEM   <= 0;
        inst_csrxchg_MEM <= 0;
        inst_ertn_MEM    <= 0;
        inst_syscall_MEM <= 0;
        inst_break_MEM   <= 0;
        inst_addr_wrong_MEM <= 0;
        mem_addr_wrong_MEM  <= 0;
        invalid_inst_MEM    <= 0;
        count_data_MEM      <= 0;
        read_count_data_MEM <= 0;
        is_store_inst_MEM   <= 0;
        is_load_inst_MEM    <= 0;
        ex_MEM <= 0;
        tlbsrch_hit_MEM     <= 0;
        tlb_refill_MEM  <= 0;
        pte_invalid_load_MEM <= 0;
        pte_invalid_store_MEM <= 0;
        pte_invalid_fetch_MEM <= 0;
        pte_plv_invalid_MEM <= 0;
        pte_m_e_MEM <= 0;
        adem_detected_MEM <= 0;
    end
end

//MEM_TO_WB
always @(posedge clk) begin
    if (valid_MEM_TO_WB && allow_in_WB) begin
        pc_WB           <= pc_MEM;
        gr_we_WB        <= gr_we_MEM;
        dest_WB         <= dest_MEM;
        rkd_value_WB    <= rkd_value_MEM;
        rj_value_WB     <= rj_value_MEM;
        final_result_WB <= final_result_MEM;
        ex_WB           <= ex_MEM_occur & ~(ex_WB_occur | ertn_flush);
        csr_num_WB      <= csr_num_MEM;
        inst_csrrd_WB   <= inst_csrrd_MEM;
        inst_csrwr_WB   <= inst_csrwr_MEM;
        inst_csrxchg_WB <= inst_csrxchg_MEM;
        inst_ertn_WB    <= inst_ertn_MEM & ~(ex_WB_occur | ertn_flush);
        inst_syscall_WB <= inst_syscall_MEM;
        inst_break_WB   <= inst_break_MEM;
        is_csr_WB       <= is_csr_MEM;
        inst_addr_wrong_WB <= inst_addr_wrong_MEM;
        mem_addr_wrong_WB  <= mem_addr_wrong_MEM;
        invalid_inst_WB <= invalid_inst_MEM;
        vaddr_WB        <= vaddr_MEM;
        tlbsrch_hit_WB  <= tlbsrch_hit_MEM;
        inst_tlbsrch_WB <= inst_tlbsrch_MEM;
        inst_tlbfill_WB <= inst_tlbfill_MEM;
        inst_tlbwr_WB   <= inst_tlbwr_MEM;
        inst_tlbrd_WB   <= inst_tlbrd_MEM;
        tlb_refill_WB   <= tlb_refill_MEM && ~ex_MMU_WB && ~refetch_tlb_WB;
        pte_invalid_load_WB <= pte_invalid_load_MEM;
        pte_invalid_store_WB <= pte_invalid_store_MEM;
        pte_invalid_fetch_WB <= pte_invalid_fetch_MEM;
        pte_plv_invalid_WB <= pte_plv_invalid_MEM;
        pte_m_e_WB <= pte_m_e_MEM;
        adem_detected_WB <= adem_detected_MEM;
    end
    else if((ex_WB_occur | ertn_flush) || ex_MMU_WB || refetch_tlb_WB)begin
        ex_WB           <= 0;
        inst_ertn_WB    <= 0;
    end
end
// 这里只有单独赋值比较好实现条件判断的优先级
// 像1179行那种方法我试过不行，所以考虑这种单独写一个always块赋值的方法
always @(posedge clk) begin
    if (reset) begin
        refetch_tlb_WB <= 0;
    end
    else if (refetch_tlb_WB) begin
        refetch_tlb_WB <= 0;
    end
    else if (valid_MEM_TO_WB && allow_in_WB) begin
        refetch_tlb_WB  <= refetch_tlb_MEM;
    end
end

always @(posedge clk) begin
    if (reset) begin
        ex_MMU_WB <= 0;
    end
    if (ex_MMU_WB) begin
        ex_MMU_WB <= 0;
    end
    else if (valid_MEM_TO_WB && allow_in_WB) begin
        ex_MMU_WB  <= ex_MMU_MEM;
    end
end

//WB_TO_IF
always @(posedge clk) begin
    WB_TO_IF_bus<=ex_WB_occur|inst_ertn_WB; 
end
//WB_TO_ID
always @(posedge clk) begin
    WB_TO_ID_bus<=ex_WB_occur|inst_ertn_WB; 
end
//WB_TO_EX
always @(posedge clk) begin
    WB_TO_EX_bus<=ex_WB_occur|inst_ertn_WB; 
end
//WB_TO_MEM
always @(posedge clk) begin
    WB_TO_MEM_bus<=ex_WB_occur|inst_ertn_WB; 
end
//MEM_TO_EX
always @(posedge clk) begin
    MEM_TO_EX_bus<=ex_MEM_occur | inst_ertn_MEM; 
end
assign is_csr_WB_block = (inst_csrwr_EX  | inst_csrxchg_EX | inst_ertn_EX)  & (valid_EX & csr_num_EX == csr_num)  |
                      (inst_csrwr_MEM | inst_csrxchg_MEM| inst_ertn_MEM) & (valid_MEM & csr_num_MEM == csr_num);


always @(posedge clk) begin
    if (reset) begin
        ertn_doing <= 0;
    end
    else if (inst_ertn && !(is_load_inst_EX || is_store_inst_EX)) begin
        ertn_doing <= 1;
    end
    else if (ertn_done || ertn_finish) begin
        ertn_doing <= 0;
    end
end

always @(posedge clk) begin
    if (reset) begin
        ertn_done <= 0;
    end
    else if(inst_ertn)begin
        ertn_done <= 0;
    end
    else if (ertn_flush) begin
        ertn_done <= 1;
    end
end

always @(posedge clk) begin
    if (reset) begin
        ertn_finish <= 0;
    end
    else if(ertn_flush && inst_ertn)begin
        ertn_finish <= 1;
    end
    else if (!inst_ertn) begin
        ertn_finish <= 0;
    end
end
//-------------------------------------------------------------------------

//inst_sram
assign inst_sram_req   = !reset && allow_in_IF && ~br_blocked && ~mid_handshake_inst && ~tlb_refill_pre_IF && ~pte_invalid_fetch;
assign inst_sram_size  = 2'b10; 
assign inst_sram_wr    = 1'b0;
assign inst_sram_wstrb = 4'b0;
assign inst_sram_addr  = trans_pc;
assign inst_sram_wdata = 32'b0;

//inst_info
assign op_31_26  = inst[31:26];
assign op_25_22  = inst[25:22];
assign op_21_20  = inst[21:20];
assign op_19_15  = inst[19:15];

assign rd   = inst[ 4: 0];
assign rj   = inst[ 9: 5];
assign rk   = inst[14:10];

assign i12  = inst[21:10];
assign i20  = inst[24: 5];
assign i16  = inst[25:10];
assign i26  = {inst[ 9: 0], inst[25:10]};
assign csr_num  =  inst_rdcntid? 14'h40 :
                (inst_ertn | inst_syscall)? 14'h6 : inst[23:10];

//inst_identify
decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];


assign inst_mul_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_div_wu     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_mod_wu     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];
assign inst_blt    = op_31_26_d[6'h18];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bgeu   = op_31_26_d[6'h1b];
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign inst_tlbsrch = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & ~inst[14] & inst[13] & ~inst[12] & inst[11] & ~inst[10] && rj==5'b0 && rd==5'b0;
assign inst_tlbrd = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & ~inst[14] & inst[13] & ~inst[12] & inst[11] & inst[10] && rj==5'b0 && rd==5'b0; 
assign inst_tlbwr = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & ~inst[14] & inst[13] & inst[12] & ~inst[11] & ~inst[10] && rj==5'b0 && rd==5'b0;
assign inst_tlbfill = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & ~inst[14] & inst[13] & inst[12] & ~inst[11] & inst[10] && rj==5'b0 && rd==5'b0 ;
assign inst_invtlb =   op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];

/* add inst identify for new inst in exp10 */
/* author: hyx                             */
assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h08];
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h09];
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'h0d];
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'h0e];
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'h0f];

assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h00] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h00] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h00] & op_21_20_d[2'h1] & op_19_15_d[5'h10];

assign inst_pcaddu12i = op_31_26_d[6'h07] & ~inst[25];

/* add new inst for exp12 */
/* author: ljw            */
assign inst_csrrd  = op_31_26_d[6'h01] & ~inst[25] & ~inst[24] & ~inst[6] & ~inst[7] & ~inst[8] & ~inst[9] & ~inst[5];
assign inst_csrwr  = op_31_26_d[6'h01] & ~inst[25] & ~inst[24] & ~inst[6] & ~inst[7] & ~inst[8] & ~inst[9] & inst[5];
assign inst_csrxchg= op_31_26_d[6'h01] & ~inst[25] & ~inst[24] & (inst[6] | inst[7] | inst[8] | inst[9]);
assign inst_ertn   = op_31_26_d[6'h01] & op_25_22_d[4'h09] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & ~inst[14] & inst[13] & inst[12] & inst[11] & ~inst[10];
assign inst_syscall= op_31_26_d[6'h00] & op_25_22_d[4'h00] & op_21_20_d[2'h2] & op_19_15_d[5'h16]; 
assign inst_break  = op_31_26_d[6'h00] & op_25_22_d[4'h00] & op_21_20_d[2'h2] & op_19_15_d[5'h14]; 
assign inst_rdcntvh = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & inst[14] & inst[13] & ~inst[12] & ~inst[11] & inst[10] & rj == 5'b0;
assign inst_rdcntvl = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & inst[14] & inst[13] & ~inst[12] & ~inst[11] & ~inst[10] & rj == 5'b0;
assign inst_rdcntid = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & inst[14] & inst[13] & ~inst[12] & ~inst[11] & ~inst[10] & rd == 5'b0;

assign invalid_inst = (!(inst_add_w | inst_sub_w | inst_slt | inst_sltu |
                        inst_mul_w | inst_mulh_w | inst_mulh_wu | inst_div_w | inst_div_wu |inst_mod_w | inst_mod_wu |
                        inst_nor | inst_and | inst_or | inst_xor | inst_slli_w | inst_srli_w | inst_srai_w | 
                        inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | inst_b | inst_bl | inst_beq | inst_bne |
                        inst_lu12i_w | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_ld_b | inst_ld_h | inst_ld_bu |
                        inst_ld_hu | inst_st_b | inst_st_h |
                        inst_slti | inst_sltui | inst_andi | inst_ori | inst_xori | 
                        inst_sll_w | inst_srl_w | inst_sra_w | inst_pcaddu12i |
                        inst_csrrd | inst_csrwr | inst_csrxchg | inst_ertn | inst_syscall | inst_break | inst_rdcntvh | inst_rdcntvl | inst_rdcntid | inst_tlbfill | inst_tlbrd | inst_tlbsrch | inst_tlbwr | inst_invtlb) | ex_invtlb) & !ertn_doing;
                       

//alu_op
assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                               | inst_jirl   | inst_bl   | inst_pcaddu12i | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_st_b | inst_st_h;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu| inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or  | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;

//control_signals_data
assign need_ui5    =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12   =  inst_addi_w | inst_ld_w   | inst_st_w | inst_slti | inst_sltui | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_st_b | inst_st_h;
assign need_si12_u =  inst_andi   | inst_ori    | inst_xori;
assign need_si16   =  inst_jirl   | inst_beq    | inst_bne | inst_blt | inst_bltu | inst_bge | inst_bgeu;
assign need_si20   =  inst_lu12i_w| inst_pcaddu12i;
assign need_si26   =  inst_b      | inst_bl;
assign src2_is_4   =  inst_jirl   | inst_bl;

//data_prepare
assign imm = src2_is_4   ? 32'h4                      :
             need_si20   ? {i20[19:0]    , 12'b0}     :
             need_si12_u ? {20'h0        , i12[11:0]} :
/*need_ui5 || need_si12*/  {{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
       {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

//control_signals
/* author: ljw            */
assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w | inst_blt | inst_bltu | inst_bge | inst_bgeu | inst_st_b | inst_st_h | inst_csrxchg | inst_csrrd | inst_csrwr | inst_csrxchg;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w   |
                       inst_srli_w   |
                       inst_srai_w   |
                       inst_addi_w   |
                       inst_andi     |
                       inst_ori      |
                       inst_xori     |
                       inst_ld_w     |  
                       inst_st_w     |
                       
                       inst_lu12i_w  |
                       inst_pcaddu12i|

                       inst_slti     |
                       inst_sltui    |

                       inst_jirl     |
                       inst_bl       |


                       inst_ld_b     |
                       inst_ld_bu    |
                       inst_ld_h     |
                       inst_ld_hu    |
                       inst_st_b     |
                       inst_st_h     ;
assign res_from_mem_ID = inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu;

assign dst_is_r1     = inst_bl;

assign gr_we_ID = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b & ~inst_blt & ~inst_bltu & ~inst_bge & ~inst_bgeu & ~inst_st_b & ~inst_st_h & ~inst_syscall & ~inst_tlbfill & ~inst_tlbrd & ~inst_tlbsrch & ~inst_tlbwr & ~inst_invtlb & valid_ID;

assign mem_we_ID = (inst_st_w | inst_st_b | inst_st_h) & valid_ID;

assign dest_ID = inst_rdcntid? rj : dst_is_r1 ? 5'd1 : rd;

//reg_file
assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
            .clk    (clk      ),
            .raddr1 (rf_raddr1),
            .rdata1 (rf_rdata1),
            .raddr2 (rf_raddr2),
            .rdata2 (rf_rdata2),
            .we     (rf_we    ),
            .waddr  (rf_waddr ),
            .wdata  (rf_wdata )
        );

assign rj_value  = rf_rdata1;
assign rkd_value_ID = rf_rdata2;

//branch
assign rj_eq_rd = (src1_after_forward == src2_after_forward);
assign {adder_cout, adder_result} = src1_after_forward + ~src2_after_forward + 1'b1;
assign rj_lt_rd = (src1_after_forward[31] & ~src2_after_forward[31]) | ((src1_after_forward[31] ~^ src2_after_forward[31]) & adder_result[31]);
assign rj_ge_rd = !rj_lt_rd;
assign rj_ltu_rd = adder_cout&&~rj_eq_rd;
assign rj_geu_rd = !rj_ltu_rd;
assign br_taken = (   inst_beq  &&  rj_eq_rd
                      || inst_bne  && !rj_eq_rd
                      || inst_jirl
                      || inst_bl
                      || inst_b
                      || inst_blt && rj_lt_rd
                      || inst_bge && rj_ge_rd
                      || inst_bltu && rj_ltu_rd
                      || inst_bgeu && rj_geu_rd
                  )  &  valid_ID & ~RAW_BLOCK;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b || inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (pc_ID + br_offs) :
       /*inst_jirl*/ (src1_after_forward + jirl_offs);

//alu
assign alu_src1_ID = src1_is_pc  ? pc_ID[31:0] : src1_after_forward;
assign alu_src2_ID = src2_is_imm ? imm : src2_after_forward;

alu u_alu(
    .alu_op     (alu_op_EX    ),
    .alu_src1   (alu_src1_EX  ), 
    .alu_src2   (alu_src2_EX  ),
    .alu_result (alu_result_EX_alu)
    );

/* add new inst for exp10 */
/* author: ljw            */
//mul result
assign unsigned_prod   = alu_src1_EX * alu_src2_EX;
assign signed_prod     = $signed(alu_src1_EX) * $signed(alu_src2_EX);
assign mul_result      = signed_prod[31:0];
assign mulhu_result    = unsigned_prod[63:32];
assign mulh_result     = signed_prod[63:32];
  

assign dividend     = alu_src1_EX;  
assign divisor      = alu_src2_EX;  


my_div_unsigned my_div_unsigned (
    .aclk                  (clk),
    .s_axis_dividend_tdata (dividend),
    .s_axis_dividend_tready(unsigned_dividend_tready),
    .s_axis_dividend_tvalid(unsigned_dividend_tvalid),
    .s_axis_divisor_tdata  (divisor),
    .s_axis_divisor_tready (unsigned_divisor_tready),
    .s_axis_divisor_tvalid (unsigned_divisor_tvalid),
    .m_axis_dout_tdata     (unsigned_divider_res),
    .m_axis_dout_tvalid    (unsigned_dout_tvalid)
);


my_div_signed my_div_signed (
    .aclk                  (clk),
    .s_axis_dividend_tdata (dividend),
    .s_axis_dividend_tready(signed_dividend_tready),
    .s_axis_dividend_tvalid(signed_dividend_tvalid),
    .s_axis_divisor_tdata  (divisor),
    .s_axis_divisor_tready (signed_divisor_tready),
    .s_axis_divisor_tvalid (signed_divisor_tvalid),
    .m_axis_dout_tdata     (signed_divider_res),
    .m_axis_dout_tvalid    (signed_dout_tvalid)
);


always @(posedge clk) begin
    if(inst_div_w_EX || inst_mod_w_EX)
    begin
        if(signed_divisor_tready & signed_dividend_tready )
        begin
        signed_divisor_tvalid <= 1'b0;
        signed_dividend_tvalid <= 1'b0;
        end  
        else if(~last)begin
        signed_divisor_tvalid <= 1'b1;
        signed_dividend_tvalid <= 1'b1;
        last <= 1'b1;
        end
        else if(signed_dout_tvalid && last)begin
        last <= 1'b0;
    end
    end
    else begin
        signed_divisor_tvalid <= 1'b0;
        signed_dividend_tvalid <= 1'b0;
        last <= 1'b0;
    end
end
always @(posedge clk)begin
    if(inst_div_wu_EX || inst_mod_wu_EX)
    begin
        if(unsigned_divisor_tready & unsigned_dividend_tready )
        begin
        unsigned_divisor_tvalid <= 1'b0;
        unsigned_dividend_tvalid <= 1'b0;
        end  
        else if(~u_last)begin
        unsigned_divisor_tvalid <= 1'b1;
        unsigned_dividend_tvalid <= 1'b1;
        u_last <= 1'b1;
        end
        else if(unsigned_dout_tvalid && u_last)begin
        u_last <= 1'b0;
    end
    end
    else begin
        unsigned_divisor_tvalid <= 1'b0;
        unsigned_dividend_tvalid <= 1'b0;
        u_last <= 1'b0;
    end
end
/* add new inst for exp10 */
/* author: ljw            */

assign alu_result_EX =(inst_div_w_EX)  ? signed_divider_res[63:32]   :
                      (inst_mod_w_EX)  ? signed_divider_res[31:0]    :
                      (inst_div_wu_EX) ? unsigned_divider_res[63:32] :
                      (inst_mod_wu_EX) ? unsigned_divider_res[31:0]  :
                      (inst_mul_w_EX)  ? mul_result                  :
                      (inst_mulh_w_EX) ? mulh_result                 : 
                      (inst_mulh_wu_EX)? mulhu_result                :
                      alu_result_EX_alu                              ;
//data_sram
assign data_sram_wr  = (inst_st_b_EX || inst_st_h_EX || inst_st_w_EX)? 1'b1 : 1'b0;
assign data_sram_req = !reset && valid_EX && allow_in_MEM && ~need_to_drop_MEM_R 
                        && ~pte_invalid_load && ~pte_invalid_store && ~pte_m_e && ~pte_plv_invalid
                        && (is_load_inst_EX ||is_store_inst_EX ) ? 1'b1 : 1'b0;
assign addr_low_EX = alu_result_EX[1:0];

assign data_sram_wstrb = mem_we_EX & valid_EX ? ((MEM_TO_EX_bus | WB_TO_EX_bus | ex_MEM_occur | ex_EX_occur | ex_WB_occur | ertn_doing | ex_MMU_EX | ex_MMU_MEM | refetch_tlb_EX | refetch_tlb_MEM) ? 4'b0000 :
                        
                        ({4{inst_st_b_EX && (addr_low_EX == 2'b00)}} & 4'b0001|
                        {4{inst_st_b_EX && (addr_low_EX == 2'b01)}} & 4'b0010 |
                        {4{inst_st_b_EX && (addr_low_EX == 2'b10)}} & 4'b0100 |
                        {4{inst_st_b_EX && (addr_low_EX==2'b11)}} & 4'b1000   |
                        {4{inst_st_h_EX && (addr_low_EX == 2'b10)}} & 4'b1100 |
                        {4{inst_st_h_EX && (addr_low_EX == 2'b00)}} & 4'b0011 |
                        {4{inst_st_w_EX}} & 4'b1111)) : 4'h0;

assign data_sram_addr  = trans_addr_ex;

assign data_sram_size  = (inst_st_w_EX || inst_ld_w_EX)                  ? 2'b10 :          
                         (inst_st_h_EX || inst_ld_h_EX || inst_ld_hu_EX) ? 2'b01 :         
                         (inst_st_b_EX || inst_ld_b_EX || inst_ld_bu_EX) ? 2'b00 : 2'b00;   

assign data_sram_wdata = inst_st_b_EX ? {4{rkd_value_EX[ 7:0]}} :
                         inst_st_h_EX ? {2{rkd_value_EX[15:0]}} :
                                          rkd_value_EX[31:0];

always @(posedge clk)begin
    if(reset)begin
        data_sram_rdata_R <= 32'b0;
    end
    else if(data_sram_data_ok && ~allow_in_WB)begin
        data_sram_rdata_R <= data_sram_rdata;
    end
end

always @(posedge clk)begin
    if(reset)begin
        data_sram_rdata_valid <= 1'b0;
    end
    else if(data_sram_data_ok && ~allow_in_WB)begin
        data_sram_rdata_valid <= 1'b1;
    end
    else if(ready_go_MEM && allow_in_WB)begin
        data_sram_rdata_valid <= 1'b0;
    end
end
assign final_data_sram_rdata = data_sram_rdata_valid ? data_sram_rdata_R : data_sram_rdata;
                                          
//extend ld data
assign vaddr = alu_result_EX;
assign addr_low_MEM = alu_result_MEM[1:0];
assign ld_b_data = (addr_low_MEM == 2'b00) ? {{24{final_data_sram_rdata[7]}} , final_data_sram_rdata[7:0]}:
       (addr_low_MEM == 2'b01)? {{24{final_data_sram_rdata[15]}}, final_data_sram_rdata[15:8]}:
       (addr_low_MEM == 2'b10)? {{24{final_data_sram_rdata[23]}}, final_data_sram_rdata[23:16]}:
       (addr_low_MEM == 2'b11)? {{24{final_data_sram_rdata[31]}}, final_data_sram_rdata[31:24]}: 0;
assign ld_bu_data = (addr_low_MEM == 2'b00)? {24'h000000, final_data_sram_rdata[7:0]}:
       (addr_low_MEM == 2'b01)? {24'h000000, final_data_sram_rdata[15:8]}:
       (addr_low_MEM == 2'b10)? {24'h000000, final_data_sram_rdata[23:16]}:
       (addr_low_MEM == 2'b11)? {24'h000000, final_data_sram_rdata[31:24]}:0;
assign ld_h_data = (addr_low_MEM == 2'b10)? {{16{final_data_sram_rdata[31]}},final_data_sram_rdata[31:16]} : {{16{final_data_sram_rdata[15]}},final_data_sram_rdata[15:0]};
assign ld_hu_data = (addr_low_MEM == 2'b10)? {16'h0000,final_data_sram_rdata[31:16]} : {16'h0000,final_data_sram_rdata[15:0]};
assign mem_result = inst_ld_b_MEM  ? ld_b_data :
       inst_ld_bu_MEM ? ld_bu_data:
       inst_ld_h_MEM  ? ld_h_data :
       inst_ld_hu_MEM ? ld_hu_data:
       final_data_sram_rdata;


assign mem_addr_wrong = (inst_ld_h_EX || inst_ld_hu_EX) && !(addr_low_EX == 2'b00 || addr_low_EX == 2'b10) ||
                        (inst_ld_w_EX)                  && !(addr_low_EX == 2'b00)                         ||
                        (inst_st_h_EX)                  && !(addr_low_EX == 2'b00 || addr_low_EX == 2'b10) ||
                        (inst_st_w_EX)                  && !(addr_low_EX == 2'b00);

assign final_result_MEM = (read_count_data_MEM === 1) ? count_data_MEM : 
                          res_from_mem_MEM            ? mem_result : 
                                                        alu_result_MEM;

assign csr_re        = inst_csrrd_WB | inst_csrwr_WB | inst_csrxchg_WB | inst_syscall_WB;
assign csr_we        = (inst_csrwr_WB | inst_csrxchg_WB) & valid_WB;   
assign csr_wmask_WB  = inst_csrwr_WB ? 32'hffffffff : inst_csrxchg_WB ? rj_value_WB : 32'h00000000; 

assign csr_wvalue    = is_csr_WB? (rkd_value_WB & csr_wmask_WB):
                       inst_syscall_WB? pc_WB : 32'h00000000;
                       

assign ecode_WB = tlb_refill_WB         ? 6'h3f:
                  pte_invalid_load_WB   ? 6'h1 :
                  pte_invalid_store_WB  ? 6'h2 :
                  pte_invalid_fetch_WB  ? 6'h3 :
                  pte_plv_invalid_WB    ? 6'h7 :
                  pte_m_e_WB            ? 6'h4 :
                  inst_addr_wrong_WB || 
                  adem_detected_WB      ? 6'h8 : 
                  mem_addr_wrong_WB     ? 6'h9 : 
                  inst_syscall_WB       ? 6'hb :
                  inst_break_WB         ? 6'hc :
                  invalid_inst_WB       ? 6'hd :
                                          6'h0 ;

assign esubcode_WB = adem_detected_WB ? 9'b1 : 9'b0;

assign ertn_flush = inst_ertn_WB;
assign csr_tlb_input = {
    inst_tlbwr_WB,
    inst_tlbfill_WB,
    inst_tlbsrch_EX,
    inst_tlbrd_WB,
    s1_found,
    s1_index,
    r_e,
    r_vppn,
    r_ps,
    r_asid,
    r_g,
    r_ppn0,
    r_plv0,
    r_mat0,
    r_d0,
    r_v0,
    r_ppn1,
    r_plv1,
    r_mat1,
    r_d1,
    r_v1
};
assign {we,     
        w_index,
        w_e,    
        w_vppn, 
        w_ps,   
        w_asid,
        w_g,    
        w_ppn0, 
        w_plv0, 
        w_mat0, 
        w_d0,   
        w_v0,   
        w_ppn1, 
        w_plv1,
        w_mat1,
        w_d1,  
        w_v1,  
        r_index
       } = csr_tlb_output;
CSR CSR(
    .clk(clk),
    .reset(reset),
    .csr_re(csr_re),
    .csr_we(csr_we),
    .valid_WB(valid_WB),
    .csr_num(csr_num_WB),
    .csr_wvalue(csr_wvalue),
    .csr_wmask_WB(csr_wmask_WB),
    //.has_int(has_int),
    //.hw_int_in(hw_int_in),
    .ertn_flush(ertn_flush),
    .ex_WB(ex_WB_occur && inst_ex_valid),
    .pc_WB(pc_WB),
    .vaddr_WB(vaddr_WB),
    .ecode_WB(ecode_WB),
    .esubcode_WB(esubcode_WB),
    .ex_refill(tlb_refill_WB),
    .csr_tlb_input(csr_tlb_input),
    .csr_rvalue(csr_rvalue),
    .ex_entry(ex_entry),
    .csr_estat_is_data(csr_estat_is),
    .csr_ecfg_lie_data(csr_ecfg_lie),
    .csr_crmd_ie_data(csr_crmd_ie),
    .csr_crmd_plv_data(csr_crmd_plv),
    .csr_tlb_output(csr_tlb_output),
    .csr_asid_rvalue(csr_asid_rvalue),
    .csr_tlbehi_rvalue(csr_tlbehi_rvalue),
    .csr_crmd_rvalue(csr_crmd_rvalue),
    .csr_dmw0_rvalue(csr_dmw0_rvalue),
    .csr_dmw1_rvalue(csr_dmw1_rvalue),
    .csr_tlbrentry_rvalue(csr_tlbrentry_rvalue)
);
tlb tlb(
    .clk           (clk            ),
    // search port 0 (for fetch)
    .s0_vppn       (s0_vppn        ),
    .s0_va_bit12   (s0_va_bit12    ),
    .s0_asid       (s0_asid        ),
    .s0_found      (s0_found       ),
    .s0_index      (s0_index       ),
    .s0_ppn        (s0_ppn         ),  
    .s0_ps         (s0_ps          ),
    .s0_plv        (s0_plv         ),
    .s0_mat        (s0_mat         ),
    .s0_d          (s0_d           ),
    .s0_v          (s0_v           ),
    // search port 1 (for load/store)
    .s1_vppn       (s1_vppn        ),
    .s1_va_bit12   (s1_va_bit12    ),
    .s1_asid       (s1_asid        ),
    .s1_found      (s1_found       ),
    .s1_index      (s1_index       ),
    .s1_ppn        (s1_ppn         ),
    .s1_ps         (s1_ps          ),
    .s1_plv        (s1_plv         ),
    .s1_mat        (s1_mat         ),
    .s1_d          (s1_d           ),
    .s1_v          (s1_v           ),
    // invtlb opcode
    .invtlb_op     (invtlb_op      ),
    .invtlb_valid   (inst_invtlb_EX ),
    // write port
    .we            (we             ),
    .w_index       (w_index        ),
    .w_e           (w_e            ),
    .w_ps          (w_ps           ),
    .w_vppn        (w_vppn         ),
    .w_asid        (w_asid         ),
    .w_g           (w_g            ),
    .w_ppn0        (w_ppn0         ),
    .w_plv0        (w_plv0         ),
    .w_mat0        (w_mat0         ),
    .w_d0          (w_d0           ),
    .w_v0          (w_v0           ),
    .w_ppn1        (w_ppn1         ),
    .w_plv1        (w_plv1         ),
    .w_mat1        (w_mat1         ),
    .w_d1          (w_d1           ),
    .w_v1          (w_v1           ),
    // read port
    .r_index       (r_index        ),
    .r_e           (r_e            ),
    .r_vppn        (r_vppn         ),
    .r_ps          (r_ps           ),
    .r_asid        (r_asid         ),
    .r_g           (r_g            ),
    .r_ppn0        (r_ppn0         ),
    .r_plv0        (r_plv0         ),
    .r_mat0        (r_mat0         ),
    .r_d0          (r_d0           ),
    .r_v0          (r_v0           ),
    .r_ppn1        (r_ppn1         ),     
    .r_plv1        (r_plv1         ),
    .r_mat1        (r_mat1         ),
    .r_d1          (r_d1           ),
    .r_v1          (r_v1           )
);
//tlb例外
assign is_mapping_vaddr_if  = ~(da_hit || dmw0_hit_pre_if || dmw1_hit_pre_if);
assign is_mapping_vaddr_ex  = ~(da_hit || dmw0_hit_ex || dmw1_hit_ex);

assign tlb_refill_pre_IF = is_mapping_vaddr_if && ~s0_found;
assign tlb_refill_EX     = is_mapping_vaddr_ex && ~s1_found && ( is_load_inst_EX || is_store_inst_EX);
assign pte_invalid_load  = is_mapping_vaddr_ex && is_load_inst_EX  && s1_found && ~s1_v;
assign pte_invalid_store = is_mapping_vaddr_ex && is_store_inst_EX && s1_found && ~s1_v;
assign pte_invalid_fetch = is_mapping_vaddr_if && s0_found && ~s0_v;
assign pte_plv_invalid   = (is_mapping_vaddr_ex ) && (is_load_inst_EX || is_store_inst_EX) && (s1_found && s1_v && 
                            (s1_plv == 2'b00 && (csr_crmd_plv == 2'b01 || csr_crmd_plv == 2'b10 || csr_crmd_plv == 2'b11) || 
                            s1_plv == 2'b01 && (csr_crmd_plv == 2'b10 || csr_crmd_plv == 2'b11) ||
                            s1_plv == 2'b10 && (csr_crmd_plv == 2'b11)));// 避免直接使用大于符号

assign pte_m_e           = is_mapping_vaddr_ex && is_store_inst_EX && s1_found && s1_v && ~s1_d;

//访存地址的虚实地址转换
assign tlbsrch_hit = inst_tlbsrch_EX && s1_found;
assign s1_vppn = inst_invtlb_EX ? rkd_value_EX[31:13] : 
                 inst_tlbsrch_WB ? csr_tlbehi_rvalue[31:13] :
                                    alu_result_EX[31:13];
assign s1_asid = inst_invtlb_EX ? rj_value_EX[9:0] : csr_asid_rvalue[9:0];
assign s1_va_bit12 = inst_invtlb ? rkd_value_EX[12]: 
                     inst_tlbsrch ? 1'b0 : alu_result_EX[12]; 
//之前这里的后缀都是mem，现在改为ex，因为是在ex级处理
assign dmw0_hit_ex = (csr_crmd_rvalue[1:0] == 2'b00 && csr_dmw0_rvalue[0]   ||
                   csr_crmd_rvalue[1:0] == 2'b11 && csr_dmw0_rvalue[3] ) && (alu_result_EX[31:29] == csr_dmw0_rvalue[31:29]); 
assign dmw1_hit_ex = (csr_crmd_rvalue[1:0] == 2'b00 && csr_dmw1_rvalue[0]   ||
                   csr_crmd_rvalue[1:0] == 2'b11 && csr_dmw1_rvalue[3] ) && (alu_result_EX[31:29] == csr_dmw1_rvalue[31:29]); 
assign dmw_addr_ex = {32{dmw0_hit_ex}} & {csr_dmw0_rvalue[27:25], alu_result_EX[28:0]} |
                  {32{dmw1_hit_ex}} & {csr_dmw1_rvalue[27:25], alu_result_EX[28:0]};
assign tlb_addr_ex = s1_ps == 6'd12 ? {s1_ppn[19:0],alu_result_EX[11:0]} :
                                   {s1_ppn[19:10],alu_result_EX[21:0]};
assign trans_addr_ex =   da_hit ?             alu_result_EX  :
                    dmw0_hit_ex||dmw1_hit_ex ? dmw_addr_ex       :
                                         tlb_addr_ex         ;
assign invtlb_op = rd;
assign adem = is_mapping_vaddr_ex && vaddr[31];
assign adem_detected = adem & ~mem_addr_wrong & (is_load_inst_EX || is_store_inst_EX);

Counter Counter(
    .reset(reset),
    .clk(clk),
    .read(read_count_data_h_EX),
    .out_time(count_data)
);
assign is_csr_EX   = inst_csrrd_EX | inst_csrwr_EX | inst_csrxchg_EX | inst_rdcntid_EX;
assign rf_we       = gr_we_WB & valid_WB & !ex_WB_occur & !ex_MMU_WB && !refetch_tlb_WB;
assign rf_waddr    = dest_WB;
assign rf_wdata    = is_csr_WB? csr_rvalue : final_result_WB;
// debug info generate
assign debug_wb_pc       = pc_WB;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata;

endmodule
