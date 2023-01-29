module Counter(
    input wire reset,
    input wire clk,
    input wire read,//为1读高32位，为0读低32位
    output wire [31:0] out_time
);
reg [63:0] timer_cnt;
always @(posedge clk) begin
    if(reset)
        timer_cnt <= 64'h0;
    else
        timer_cnt <= timer_cnt+1;
end
assign out_time = read? timer_cnt[63:32] : timer_cnt[31:0];
endmodule