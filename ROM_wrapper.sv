//`include "AXI/AXI_Slave_interface.sv"
module ROM_wrapper(
    input clk,
    input rst,
    
	input [`AXI_IDS_BITS-1:0] AWID,
	input [`AXI_ADDR_BITS-1:0] AWADDR,
	input [`AXI_LEN_BITS-1:0] AWLEN,
	input [`AXI_SIZE_BITS-1:0] AWSIZE,
	input [1:0] AWBURST,
	input AWVALID,
	output logic AWREADY,
	//WRITE DATA0
	input [`AXI_DATA_BITS-1:0] WDATA,
	input [`AXI_STRB_BITS-1:0] WSTRB,
	input WLAST,
	input WVALID,
	output logic WREADY,
	//WRITE RESPONSE0
	output logic [`AXI_IDS_BITS-1:0] BID,
	output logic [1:0] BRESP,
	output logic BVALID,
	input BREADY,
	
	//READ ADDRESS0
	input [`AXI_IDS_BITS-1:0] ARID,
	input [`AXI_ADDR_BITS-1:0] ARADDR,
	input [`AXI_LEN_BITS-1:0] ARLEN,
	input [`AXI_SIZE_BITS-1:0] ARSIZE,
	input [1:0] ARBURST,
	input ARVALID,
	output logic ARREADY,
	//READ DATA0
	output logic [`AXI_IDS_BITS-1:0] RID,
	output logic [`AXI_DATA_BITS-1:0] RDATA,
	output logic [1:0] RRESP,
	output logic RLAST,
	output logic RVALID,
	input RREADY,

	input [31:0] ROM_out,
    output logic ROM_read,
    output logic ROM_enable,
    output logic [11:0] ROM_address
);
	logic state,next_state;
	always_ff @(posedge clk or negedge rst) begin
		if(~rst) state<=1'b0;
		else state<=next_state;
	end

	logic [`AXI_LEN_BITS-1:0] cnt;
	logic read_d_fin;
	assign read_d_fin=RREADY&RVALID&RLAST;
	always_ff @(posedge clk or negedge rst) begin
		if(~rst) cnt<=`AXI_LEN_BITS'b0;
		else if(state==1'b1) cnt<=(&read_d_fin)?`AXI_LEN_BITS'b0:(~RLAST)?cnt+`AXI_LEN_BITS'b1:cnt;
	end

	always_comb begin
		if(state==1'b0) next_state=(ARREADY&ARVALID)?1'b1:1'b0;
		else next_state=(read_d_fin&ARREADY&ARVALID)?1'b1:(read_d_fin?1'b0:1'b1);
	end

	logic [`AXI_LEN_BITS-1:0] len;
	logic [`AXI_IDS_BITS-1:0] id;
	logic [1:0] burst;
	logic [11:0] rom_addr;
	logic valid;
	assign RRESP=`AXI_RESP_OKAY;
	assign BRESP=`AXI_RESP_SLVERR;
	assign RLAST=(cnt==len);
	assign RDATA=ROM_out;
	assign RID=id;
	assign BID=`AXI_IDS_BITS'b0;

	always_ff @(posedge clk or negedge rst) begin
		if(~rst) begin
			rom_addr<=12'b0;
			id<=`AXI_IDS_BITS'b0;
			len<=`AXI_LEN_BITS'b0;
			valid<=1'b0;
		end
		else begin
			if(ARREADY&&ARVALID) begin
				rom_addr<=ARADDR[13:2];
				id<=ARID;
				len<=ARLEN;
				valid<=RVALID;
			end
			else begin
				rom_addr<=rom_addr;
				id<=id;
				len<=len;
				valid<=RVALID;
			end
		end
	end

	always_comb begin
		case (state)
			1'b0:begin
				AWREADY=1'b1;
				WREADY=1'b0;
				ARREADY=1'b1;
				RVALID=1'b0;
				BVALID=1'b0;
			end
			1'b1:begin
				AWREADY=RREADY&RVALID;
				WREADY=1'b0;
				ARREADY=1'b0;
				RVALID=1'b1;
				BVALID=1'b0;
			end
		endcase
	end

	logic [1:0] rom_offset;
	assign rom_offset = ~|cnt[1:0] ? ((RREADY & RVALID) ? cnt[1:0] + 2'b1 : cnt[1:0]) : cnt[1:0] + 2'b1;
	always_comb begin
		case (state)
			1'b0:begin
				ROM_read=ARREADY&ARVALID;
				ROM_enable=ARVALID;
				ROM_address=ARADDR[13:2];
			end
			1'b1:begin
				ROM_read=1'b1;
				ROM_enable=1'b1;
				ROM_address=rom_addr+rom_offset;
			end
		endcase
	end

endmodule