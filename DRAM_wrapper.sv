

module DRAM_wrapper (
	input clk,rst,
	// WRITE ADDRESS
    input [`AXI_IDS_BITS-1:0] AWID,
    input [`AXI_ADDR_BITS-1:0] AWADDR,
    input [`AXI_LEN_BITS-1:0] AWLEN,
    input [`AXI_SIZE_BITS-1:0] AWSIZE,
    input [1:0] AWBURST,
    input AWVALID,
    output logic AWREADY,
    // WRITE DATA
    input [`AXI_DATA_BITS-1:0] WDATA,
    input [`AXI_STRB_BITS-1:0] WSTRB,
    input WLAST,
    input WVALID,
    output logic WREADY,
    // WRITE RESPONSE
    output logic [`AXI_IDS_BITS-1:0] BID,
    output logic [1:0] BRESP,
    output logic BVALID,
    input BREADY,

    // READ ADDRESS
    input [`AXI_IDS_BITS-1:0] ARID,
    input [`AXI_ADDR_BITS-1:0] ARADDR,
    input [`AXI_LEN_BITS-1:0] ARLEN,
    input [`AXI_SIZE_BITS-1:0] ARSIZE,
    input [1:0] ARBURST,
    input ARVALID,
    output logic ARREADY,
    // READ DATA
    output logic [`AXI_IDS_BITS-1:0] RID,
    output logic [`AXI_DATA_BITS-1:0] RDATA,
    output logic [1:0] RRESP,
    output logic RLAST,
    output logic RVALID,
    input RREADY,

    output logic DRAM_CSn,
    output logic [`AXI_STRB_BITS-1:0] DRAM_WEn,
    output logic DRAM_RASn,
    output logic DRAM_CASn,
    output logic [10:0] DRAM_A,
    output logic [`AXI_DATA_BITS-1:0] DRAM_D,
    input [`AXI_DATA_BITS-1:0] DRAM_Q,
    input DRAM_valid
);
	
	/*
		state:idle:3'b000
			  act:3'b001
			  read:3'b010
			  write:3'b011
			  precharge:3'b100			
	*/
	logic [2:0] state,next_state;
	always_ff @( posedge clk or negedge rst ) begin
		if(~rst) state<=3'b000;
		else state<=next_state;
	end

	logic [2:0] delay_clk;
	logic delay_done;
	assign delay_done=(state==3'b010)?delay_clk==3'd5:delay_clk[2];
	always_ff @( posedge clk or negedge rst ) begin
		if(~rst) delay_clk<=3'b0;
		else begin
			delay_clk=(state==3'b0)?3'b0:((delay_done)?3'b0:delay_clk+3'b1);
		end
	end

	logic write;
	always_ff @( posedge clk or negedge rst ) begin
		if(~rst) write<=1'b0;
		else begin
			if(state==3'b000) write<=(AWREADY&AWVALID)?1'b1:1'b0;
			else if(state==3'b001) write<=write;
			else write<=1'b0;
		end
	end

	always_comb begin
		case(state)
			3'b000:begin
				next_state=((ARREADY&ARVALID)|(AWREADY&AWVALID))?3'b001:3'b000;
			end
			3'b001:begin
				next_state=delay_done?(write?3'b011:3'b010):3'b001;
			end
			3'b010:begin
				next_state=(delay_done&RREADY&RVALID&RLAST)?3'b100:3'b010;
			end
			3'b011:begin
				next_state=delay_done?3'b100:3'b011;
			end
			3'b100:begin
				next_state=delay_done?3'b000:3'b100;
			end
			default:begin
				next_state=delay_done?3'b000:3'b100;
			end
		endcase
	end

	logic [`AXI_ADDR_BITS-1:0] addr;
	logic [`AXI_IDS_BITS-1:0] id;
	logic [1:0] burst;
	logic [`AXI_LEN_BITS-1:0] len;
	logic [`AXI_SIZE_BITS-1:0] size;
	logic [`AXI_DATA_BITS-1:0] data;
	logic [`AXI_DATA_BITS-1:0] rdata;
	always_ff @( posedge clk or negedge rst ) begin
		if(~rst) begin
			addr<=32'b0;
			id<=`AXI_IDS_BITS'b0;
			burst<=2'b0;
			len<=`AXI_LEN_BITS'b0;
			size<=`AXI_SIZE_BITS'b0;
			data<=`AXI_DATA_BITS'b0;
			rdata<=`AXI_DATA_BITS'b0;
		end
		else begin
			if(ARREADY&&ARVALID) begin
				addr<=ARADDR;
				id<=ARID;
				burst<=ARBURST;
				len<=ARLEN;
				size<=ARSIZE;
			end
			else if(AWREADY&&AWVALID) begin
				addr<=AWADDR;
				id<=AWID;
				burst<=AWBURST;
				len<=AWLEN;
				size<=AWSIZE;
			end
			data<=(state==3'b001)?WDATA:data;
			rdata<=DRAM_valid?DRAM_Q:rdata;
		end
	end
	logic [`AXI_LEN_BITS-1:0] cnt;
	assign RID=id;
	assign RDATA=DRAM_valid?DRAM_Q:rdata;
	assign RRESP=`AXI_RESP_OKAY;
	assign RLAST=(cnt==len);
	assign BID=id;
	assign BRESP=`AXI_RESP_OKAY;

	always_ff @( posedge clk or negedge rst ) begin
		if(~rst) cnt<=`AXI_LEN_BITS'b0;
		else begin
			cnt<=(state==3'b010)?((RREADY&RVALID)?cnt+`AXI_LEN_BITS'b1:cnt):`AXI_LEN_BITS'b0;
		end
	end

	always_comb begin
		case(state)
			3'b000:begin
				DRAM_RASn=1'b1;
				DRAM_CASn=1'b1;
				DRAM_WEn=4'hf;
				DRAM_A=addr[22:12];
				DRAM_D=32'b0;
				DRAM_CSn=1'b1;
			end
			3'b001:begin
				DRAM_RASn=(delay_clk==3'b0)?1'b0:1'b1;
				DRAM_CASn=1'b1;
				DRAM_WEn=4'hf;
				DRAM_A=addr[22:12];
				DRAM_D=WDATA;
				DRAM_CSn=1'b0;
			end
			3'b010:begin
				DRAM_RASn=1'b1;
				DRAM_CASn=(delay_clk==3'b0)?1'b0:1'b1;
				DRAM_WEn=4'hf;
				DRAM_A=addr[11:2]+cnt[1:0];
				DRAM_D=WDATA;
				DRAM_CSn=1'b0;
			end
			3'b011:begin
				DRAM_RASn=1'b1;
				DRAM_CASn=(delay_clk==3'b0)?1'b0:1'b1;
				DRAM_WEn=(delay_clk==3'b0)?WSTRB:4'hf;
				DRAM_A=addr[11:2];
				DRAM_D=data;
				DRAM_CSn=1'b0;
			end
			3'b100:begin
				DRAM_RASn=(delay_clk==3'b0)?1'b0:1'b1;
				DRAM_CASn=1'b1;
				DRAM_WEn=(delay_clk==3'b0)?4'h0:4'hf;
				DRAM_A=addr[22:12];
				DRAM_D=32'b0;
				DRAM_CSn=1'b0;
			end
			default:begin
				DRAM_RASn=(delay_clk==3'b0)?1'b0:1'b1;
				DRAM_CASn=1'b1;
				DRAM_WEn=(delay_clk==3'b0)?4'h0:4'hf;
				DRAM_A=addr[22:12];
				DRAM_D=32'b0;
				DRAM_CSn=1'b0;
			end
		endcase
	end

	always_comb begin
		case(state)
			3'b000:begin
				ARREADY=~AWVALID;
				AWREADY=1'b1;
				WREADY=1'b0;
				RVALID=1'b0;
				BVALID=1'b0;
			end
			3'b001:begin
				ARREADY=1'b0;
				AWREADY=1'b0;
				WREADY=1'b0;
				RVALID=1'b0;
				BVALID=1'b0;
			end
			3'b010:begin
				ARREADY=1'b0;
				AWREADY=1'b0;
				WREADY=1'b0;
				RVALID=DRAM_valid;
				BVALID=1'b0;
			end
			3'b011:begin
				ARREADY=1'b0;
				AWREADY=1'b0;
				WREADY=1'b1;
				RVALID=1'b0;
				BVALID=1'b0;
			end
			3'b100:begin
				ARREADY=1'b0;
				AWREADY=1'b0;
				WREADY=1'b0;
				RVALID=1'b0;
				BVALID=(delay_clk==3'b0)?1'b1:1'b0;
			end
			default:begin
				ARREADY=1'b0;
				AWREADY=1'b0;
				WREADY=1'b0;
				RVALID=1'b0;
				BVALID=1'b0;
			end
		endcase
	end


endmodule
