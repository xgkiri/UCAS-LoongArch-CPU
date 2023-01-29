module tlb
#(
    parameter TLBNUM = 16
)
(
    input  wire                     clk,
    //search port 0(for fetch)
    input  wire[              18:0] s0_vppn,
    input  wire                     s0_va_bit12,
    input  wire[               9:0] s0_asid,
    output wire                     s0_found,
    output wire[$clog2(TLBNUM)-1:0] s0_index,
    output wire[              19:0] s0_ppn,
    output wire[               5:0] s0_ps,
    output wire[               1:0] s0_plv,
    output wire[               1:0] s0_mat,
    output wire                     s0_d,
    output wire                     s0_v,
    // search port 1 (for load/store)
    input  wire[              18:0] s1_vppn,
    input  wire                     s1_va_bit12,
    input  wire[               9:0] s1_asid,
    output wire                     s1_found,
    output wire[$clog2(TLBNUM)-1:0] s1_index,
    output wire[              19:0] s1_ppn,
    output wire[               5:0] s1_ps,
    output wire[               1:0] s1_plv,
    output wire[               1:0] s1_mat,
    output wire                     s1_d,
    output wire                     s1_v,
    // invtlb opcode
    input  wire[               4:0] invtlb_op,
    input  wire                     invtlb_valid,
    // write port
    input  wire                     we,
    input  wire[$clog2(TLBNUM)-1:0] w_index,
    input  wire                     w_e,
    input  wire[              18:0] w_vppn,
    input  wire[               5:0] w_ps,
    input  wire[               9:0] w_asid,
    input  wire                     w_g,
    input  wire[              19:0] w_ppn0,
    input  wire[               1:0] w_plv0,
    input  wire[               1:0] w_mat0,
    input  wire                     w_d0,
    input  wire                     w_v0,
    input  wire[              19:0] w_ppn1,
    input  wire[               1:0] w_plv1,
    input  wire[               1:0] w_mat1,
    input  wire                     w_d1,
    input  wire                     w_v1,
    // read port
    input  wire[$clog2(TLBNUM)-1:0] r_index,
    output wire                     r_e,
    output wire[              18:0] r_vppn,
    output wire[               5:0] r_ps,
    output wire[               9:0] r_asid,
    output wire                     r_g,
    output wire[              19:0] r_ppn0,
    output wire[               1:0] r_plv0,
    output wire[               1:0] r_mat0,
    output wire                     r_d0,
    output wire                     r_v0,
    output wire[              19:0] r_ppn1,
    output wire[               1:0] r_plv1,
    output wire[               1:0] r_mat1,
    output wire                     r_d1,
    output wire                     r_v1
);
reg [TLBNUM-1:0] tlb_e;
reg [TLBNUM-1:0] tlb_ps4MB; //pagesize 1:4MB, 0:4KB
reg [ 18     :0] tlb_vppn   [TLBNUM-1:0];
reg [ 9      :0] tlb_asid   [TLBNUM-1:0];
reg              tlb_g      [TLBNUM-1:0];
reg [ 19     :0] tlb_ppn0   [TLBNUM-1:0];
reg [ 1      :0] tlb_plv0   [TLBNUM-1:0];
reg [ 1      :0] tlb_mat0   [TLBNUM-1:0];
reg              tlb_d0     [TLBNUM-1:0];
reg              tlb_v0     [TLBNUM-1:0];
reg [ 19     :0] tlb_ppn1   [TLBNUM-1:0];
reg [ 1      :0] tlb_plv1   [TLBNUM-1:0];
reg [ 1      :0] tlb_mat1   [TLBNUM-1:0];
reg              tlb_d1     [TLBNUM-1:0];
reg              tlb_v1     [TLBNUM-1:0];

wire      [15:0] match0;
wire      [15:0] match1;
wire             cond1      [TLBNUM-1:0];
wire             cond2      [TLBNUM-1:0];
wire             cond3      [TLBNUM-1:0];
wire             cond4      [TLBNUM-1:0];
wire             inv_match  [TLBNUM-1:0];  

genvar i;
generate
    for(i=0;i<TLBNUM;i=i+1) begin
        //四个子匹配
        assign cond1[i] = tlb_g[i] == 0;
        assign cond2[i] = tlb_g[i] == 1;
        assign cond3[i] = tlb_asid[i] == s1_asid;
        assign cond4[i] = (s1_vppn[18:10] == tlb_vppn[i][18:10]) && (tlb_ps4MB[i] || s1_vppn[9:0]==tlb_vppn[i][9:0]);
        //INVTLB查找匹配
        assign inv_match[i] =   (invtlb_op == 0 || invtlb_op == 1) & (cond1[i] || cond2[i]) |
							    (invtlb_op == 2)                   & cond2[i]               |
							    (invtlb_op == 3)                   & cond1[i]               |
							    (invtlb_op == 4)                   & (cond1[i] && cond3[i]) |
							    (invtlb_op == 5)       & (cond1[i] && cond3[i] && cond4[i]) |
							    (invtlb_op == 6)       & ((cond2[i] || cond3[i]) && cond4[i]);
        //查找操作实现
        assign match0[i] = (s0_vppn[18:10] == tlb_vppn[i][18:10]) && (tlb_ps4MB[i] || s0_vppn[9:0] == tlb_vppn[i][9:0]) && (s0_asid == tlb_asid[i] || tlb_g[i]);
        assign match1[i] = (s1_vppn[18:10] == tlb_vppn[i][18:10]) && (tlb_ps4MB[i] || s1_vppn[9:0] == tlb_vppn[i][9:0]) && (s1_asid == tlb_asid[i] || tlb_g[i]);
        //写TLB
        always @(posedge clk)begin
            if(we && w_index==i)begin
                tlb_ps4MB[i]  <= (w_ps == 6'd22);
                tlb_vppn[i]   <= w_vppn;
                tlb_asid[i]   <= w_asid;
                tlb_g[i]      <= w_g;
                tlb_ppn0[i]   <= w_ppn0;
                tlb_plv0[i]   <= w_plv0;
                tlb_mat0[i]   <= w_mat0;
                tlb_d0[i]     <= w_d0;
                tlb_v0[i]     <= w_v0;
                tlb_ppn1[i]   <= w_ppn1;
                tlb_plv1[i]   <= w_plv1;
                tlb_mat1[i]   <= w_mat1;
                tlb_d1[i]     <= w_d1;
                tlb_v1[i]     <= w_v1;
            end
        end
        //INVTLB指令的TLB表项无效操作
        always @(posedge clk)begin
            if(inv_match[i] & invtlb_valid)begin
                tlb_e[i] <= 1'b0;
            end
            else if(we && w_index==i)begin
                tlb_e[i] <= w_e;
            end
        end
    end
endgenerate 
//确定匹配的TLB表项的序号
assign s0_index = {4{match0[ 0]}} ? 4'd0  :
                  {4{match0[ 1]}} ? 4'd1  :
                  {4{match0[ 2]}} ? 4'd2  :
                  {4{match0[ 3]}} ? 4'd3  :
                  {4{match0[ 4]}} ? 4'd4  :
                  {4{match0[ 5]}} ? 4'd5  :
                  {4{match0[ 6]}} ? 4'd6  :
                  {4{match0[ 7]}} ? 4'd7  :
                  {4{match0[ 8]}} ? 4'd8  :
                  {4{match0[ 9]}} ? 4'd9  :
                  {4{match0[10]}} ? 4'd10 :
                  {4{match0[11]}} ? 4'd11 :
                  {4{match0[12]}} ? 4'd12 :
                  {4{match0[13]}} ? 4'd13 :
                  {4{match0[14]}} ? 4'd14 :
                  4'd15;
assign s1_index = {4{match1[ 0]}} ? 4'd0  :
                  {4{match1[ 1]}} ? 4'd1  :
                  {4{match1[ 2]}} ? 4'd2  :
                  {4{match1[ 3]}} ? 4'd3  :
                  {4{match1[ 4]}} ? 4'd4  :
                  {4{match1[ 5]}} ? 4'd5  :
                  {4{match1[ 6]}} ? 4'd6  :
                  {4{match1[ 7]}} ? 4'd7  :
                  {4{match1[ 8]}} ? 4'd8  :
                  {4{match1[ 9]}} ? 4'd9  :
                  {4{match1[10]}} ? 4'd10 :
                  {4{match1[11]}} ? 4'd11 :
                  {4{match1[12]}} ? 4'd12 :
                  {4{match1[13]}} ? 4'd13 :
                  {4{match1[14]}} ? 4'd14 :
                  4'd15;
//输出信号
assign s0_found = (match0==16'b0)? 0:1;//match 是否不等于全0
assign s1_found = (match1==16'b0)? 0:1;
//判断选择的是奇数页还是偶数页
wire s0_odd = tlb_ps4MB[s0_index]?s0_vppn[9]:s0_va_bit12;
wire s1_odd = tlb_ps4MB[s1_index]?s1_vppn[9]:s1_va_bit12;
//选择奇数页还是偶数页的TLB表项的物理页号
assign s0_ppn = s0_odd ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
assign s1_ppn = s1_odd ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
//选择奇数页还是偶数页的TLB表项的物理页号的权限
assign s0_plv = s0_odd ? tlb_plv1[s0_index] : tlb_plv0[s0_index];
assign s1_plv = s1_odd ? tlb_plv1[s1_index] : tlb_plv0[s1_index];
//选择奇数页还是偶数页的TLB表项的物理页号的匹配属性
assign s0_mat = s0_odd ? tlb_mat1[s0_index] : tlb_mat0[s0_index];
assign s1_mat = s1_odd ? tlb_mat1[s1_index] : tlb_mat0[s1_index];
//选择奇数页还是偶数页的TLB表项的物理页号的dirty属性
assign s0_d = s0_odd ? tlb_d1[s0_index] : tlb_d0[s0_index];
assign s1_d = s1_odd ? tlb_d1[s1_index] : tlb_d0[s1_index];
//选择奇数页还是偶数页的TLB表项的物理页号的有效属性
assign s0_v = s0_odd ? tlb_v1[s0_index] : tlb_v0[s0_index];
assign s1_v = s1_odd ? tlb_v1[s1_index] : tlb_v0[s1_index];
//判断页大小
assign s0_ps = tlb_ps4MB[s0_index]?6'd22:6'd12;
assign s1_ps = tlb_ps4MB[s1_index]?6'd22:6'd12;

//read port
assign r_e      = tlb_e[r_index]; 
assign r_vppn   = tlb_vppn[r_index];
assign r_ps     = tlb_ps4MB[r_index] ? 6'd22 : 6'd12;
assign r_asid   = tlb_asid[r_index];
assign r_g      = tlb_g[r_index];
assign r_ppn0   = tlb_ppn0[r_index];
assign r_plv0   = tlb_plv0[r_index];
assign r_mat0   = tlb_mat0[r_index];
assign r_d0     = tlb_d0[r_index];
assign r_v0     = tlb_v0[r_index];
assign r_ppn1   = tlb_ppn1[r_index];
assign r_plv1   = tlb_plv1[r_index];
assign r_mat1   = tlb_mat1[r_index];
assign r_d1     = tlb_d1[r_index];
assign r_v1     = tlb_v1[r_index];
endmodule