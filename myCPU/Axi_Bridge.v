module Axi_Bridge (
    input wire       aclk,
    input wire       aresetn,  //复位，低电平有效
    //读请求通道
    output wire [ 3:0] arid,     //读请求ID，取指为0，取数为1
    output wire [31:0] araddr,   //读请求地址
    output wire [ 7:0] arlen,    //读请求长度,数据传输拍数，固定为0
    output wire [ 2:0] arsize,   //读请求大小，数据传输每拍的字节数
    output wire [ 1:0] arburst,  //读请求类型，固定为2'b01
    output wire [ 1:0]  arlock,   //读请求锁定，固定为0
    output wire [ 3:0] arcache,  //读请求缓存，固定为0
    output wire [ 2:0] arprot,   //读请求保护，固定为0
    output wire        arvalid,  //读请求有效，高电平有效
    input wire         arready,  //读请求准备，高电平有效，slave端准备好接收地址传输
    //读响应通道
    input wire[ 3:0] rid,      //同一请求的rid与arid一致，读响应ID，取指为0，取数为1
    input wire[31:0] rdata,    //读响应数据
    input wire [1:0] resp,
    input wire       rvalid,   //读响应有效，高电平有效
    output wire        rready,   //读响应准备，高电平有效，master端准备好接收数据传输
    //写请求通道
    output wire [ 3:0] awid,     //写请求ID，固定为1
    output wire [31:0] awaddr,   //写请求地址
    output wire [ 7:0] awlen,    //写请求长度，数据传输拍数，固定为0
    output wire [ 2:0] awsize,   //写请求大小，数据传输每拍的字节数
    output wire [ 1:0] awburst,  //写请求类型，固定为2'b01
    output wire [ 1:0] awlock,   //写请求锁定，固定为0
    output wire [ 3:0] awcache,  //写请求缓存，固定为0
    output wire [ 2:0] awprot,   //写请求保护，固定为0
    output wire        awvalid,  //写请求有效，高电平有效
    input wire       awready,  //写请求准备，高电平有效，slave端准备好接收地址传输
    //写数据通道
    output wire [ 3:0] wid,      //写请求ID，同一请求的wid与awid一致，固定为1
    output wire [31:0] wdata,    //写请求的写数据
    output wire [ 3:0] wstrb,    //写请求控制信号，字节选通位
    output wire        wlast,    //写请求最后一拍，固定为1
    output wire        wvalid,   //写请求数据握手信号，写请求数据有效
    input wire       wready,   //写请求数据握手信号，slave 端准备好接收数据传输
    //写响应通道
    input      [ 3:0] bid,//ignore
    input      [ 1:0] bresp,//ignore
    input wire       bvalid,   //写请求响应握手信号，写请求响应有效
    output wire        bready,   //写请求响应握手信号，master端准备好接收响应传输
    //inst_sram 通道
    input wire       inst_sram_req,
    input wire[ 3:0] inst_sram_wstrb,
    input wire[31:0] inst_sram_addr,
    input wire[31:0] inst_sram_wdata,
    input wire[ 1:0] inst_sram_size,
    input wire       inst_sram_wr,
    output wire [31:0] inst_sram_rdata,
    output wire        inst_sram_addr_ok,
    output wire        inst_sram_data_ok,
    //data_sram通道
    input wire       data_sram_req,
    input wire[ 3:0] data_sram_wstrb,
    input wire[31:0] data_sram_addr,
    input wire[31:0] data_sram_wdata,
    input wire[ 1:0] data_sram_size,
    input wire       data_sram_wr,
    output wire [31:0] data_sram_rdata,
    output wire        data_sram_addr_ok,
    output wire        data_sram_data_ok
);

/*-----------------状态机相关信号的定义和赋值-----------------*/
//读事务状态机相关信号
localparam READ_AINIT    = 3'b001;  //空闲状态
localparam READ_ARADDR   = 3'b010;  //读地址状态
localparam READ_RDATA    = 3'b100;  //读数据状态

reg  [2:0] read_state;          //读通道状态
reg  [2:0] read_state_next;   //读通道状态下一状态

wire read_ainit = (read_state == READ_AINIT);
wire read_araddr  = (read_state == READ_ARADDR);
wire read_rdata = (read_state == READ_RDATA);

reg reading_inst_sram;
reg reading_data_sram;

reg [31:0]rdata_R;


//写事务状态机相关信号
localparam WRITE_INIT    = 4'b0001;  //空闲状态
localparam WRITE_WADDR   = 4'b0010;  //写地址状态
localparam WRITE_WDATA   = 4'b0100;  //写数据状态
localparam WRITE_WREP    = 4'b1000;  //写响应状态

reg  [3:0] write_state;          //写通道状态
reg  [3:0] write_state_next;

wire write_init = (write_state == WRITE_INIT);
wire write_waddr = (write_state == WRITE_WADDR);
wire write_wdata = (write_state == WRITE_WDATA);
wire write_wrep = (write_state == WRITE_WREP);

reg [1:0]writing_data_sram;

/*-----------------读请求通道状态机-----------------*/
always @(posedge aclk)begin
    if(~aresetn)begin
        read_state   <= READ_AINIT;
    end
    else begin
        read_state   <= read_state_next;
    end
end

always @(*)begin
    case(read_state)
        READ_AINIT:begin
            if(((data_sram_req && ~data_sram_wr) || (inst_sram_req && ~inst_sram_wr)) && write_init)begin
                read_state_next = READ_ARADDR;
            end
            else begin
                read_state_next = READ_AINIT;
            end
        end
        READ_ARADDR:begin
            if(arvalid && arready)begin
                read_state_next = READ_RDATA;
            end
            else begin
                read_state_next = READ_ARADDR;
            end
        end
        READ_RDATA:begin
            if(rvalid && rready)begin
                read_state_next = READ_AINIT;
            end
            else begin
                read_state_next = READ_RDATA;
            end
        end
        default:
            read_state_next = READ_AINIT;
    endcase
end
//表示正在处理读指令事务，不允许其他操作
always @(posedge aclk)begin
    if(~aresetn)begin
        reading_inst_sram <= 1'b0;
    end
    else if(~data_sram_req && inst_sram_req && ~inst_sram_wr && write_init && read_ainit )begin//~data_sram_req防止互锁，使得取数据优先级比取值高
        reading_inst_sram <= 1'b1;
    end
    else if(read_rdata && rvalid && rready)begin
        reading_inst_sram <= 1'b0;
    end
end
//表示正在处理读数据事务，不允许其他操作
always @(posedge aclk)begin
    if(~aresetn)begin
        reading_data_sram <= 1'b0;
    end
    else if(read_ainit && data_sram_req && ~data_sram_wr && write_init)begin
        reading_data_sram <= 1'b1;
    end
    else if(read_rdata && rvalid && rready)begin
        reading_data_sram <= 1'b0;
    end
end
//将读取到的数据存在寄存器中
always @(posedge aclk)begin
    if(~aresetn)begin
        rdata_R <= 32'b0;
    end
    else if(read_rdata && rvalid && rready)begin
        rdata_R <= rdata;
    end
end

//读事务输出信号赋值
assign arid    = (read_araddr && reading_data_sram)?  4'h1 :
                 (read_araddr && reading_inst_sram)?  4'h0 : 4'h2;//取数为1，取指为0
assign arvalid = read_araddr;
assign arsize  = (read_araddr && reading_inst_sram) ? {1'b0,inst_sram_size} :
                 (read_araddr && reading_data_sram) ? {1'b0,data_sram_size} : 3'b0;
assign araddr  = (read_araddr && reading_inst_sram) ? inst_sram_addr :
                 (read_araddr && reading_data_sram) ? data_sram_addr : 32'b0;
assign arlen   = 8'b0;
assign arburst = 2'b1;
assign arlock  = 2'b0;
assign arcache = 4'b0;
assign arprot  = 3'b0;

assign rready = read_rdata; 


/*-----------------写事务状态机-----------------*/
always @(posedge aclk)begin
    if(~aresetn)begin
        write_state <= WRITE_INIT;
    end
    else begin
        write_state <= write_state_next;
    end
end

always @(*)begin
    case(write_state)
        WRITE_INIT:begin
            if(data_sram_req && data_sram_wr)begin
                write_state_next = WRITE_WADDR;
            end
            else begin
                write_state_next = WRITE_INIT;
            end
        end
        WRITE_WADDR:begin
            if(awvalid && awready)begin
                write_state_next = WRITE_WDATA;
            end
            else begin
                write_state_next = WRITE_WADDR;
            end
        end
        WRITE_WDATA:begin
            if(wvalid && wready)begin
                write_state_next = WRITE_WREP;
            end
            else begin
                write_state_next = WRITE_WDATA;
            end
        end
        WRITE_WREP:begin
            if(bvalid && bready)begin
                write_state_next = WRITE_INIT;
            end
            else begin
                write_state_next = WRITE_WREP;
            end
        end
        default:
            write_state_next = WRITE_INIT;
    endcase
end
//表示正在处理写数据事务，不允许其他操作 

always @(posedge aclk)begin
    if(~aresetn)begin
        writing_data_sram <= 2'b00;
    end
    else if(writing_data_sram == 2'b10)begin
        writing_data_sram <= 2'b00;
    end
    else if(awready || wready)begin
        writing_data_sram <= writing_data_sram+1;
    end
end

//写事务输出信号赋值
assign awid    = 4'b1;
assign awvalid = write_waddr;
assign awsize  = write_waddr ? {1'b0,data_sram_size} : 3'b0;
assign awaddr  = write_waddr ? data_sram_addr : 32'b0;
assign awlen   = 8'b0;
assign awburst = 2'b1;
assign awlock  = 2'b0;
assign awcache = 4'b0;
assign awprot  = 3'b0;

assign wid    = 4'b1;
assign wvalid = write_wdata;
assign wdata  = write_wdata ? data_sram_wdata : 32'b0;
assign wstrb  = write_wdata ? data_sram_wstrb : 4'b0;
assign wlast  = 1'b1;

assign bready = write_wrep;


/*-----------------返回CPU的信号赋值-----------------*/
//这里存疑，按照讲义P206，addr_ok和data_ok不能引入valid和ready
assign inst_sram_addr_ok = reading_inst_sram && arready;//在收到inst_req后，读取指令前发送addr_ok
assign data_sram_addr_ok = reading_data_sram && arready || (writing_data_sram == 2'b10);//在收到data_req后，读取数据前发送addr_ok
assign inst_sram_data_ok = reading_inst_sram && rvalid;
assign data_sram_data_ok = reading_data_sram && rvalid || bvalid;//读事务和写事务两种
assign inst_sram_rdata   = rdata;
assign data_sram_rdata   = rdata;


endmodule
