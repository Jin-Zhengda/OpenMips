`timescale 1ns / 1ps

module inst_rom(
	input wire	ce,
	input wire[`InstAddrBus] addr,
	
	output reg[`InstBus] inst
);

reg[`InstBus] inst_mem[0:`InstMemNum-1];

initial $readmemh ( "C:/Documents/Code/OpenMips/OpenMips.srcs/sim_1/new/inst_rom.mem", inst_mem );

always @ (*) begin
	if (ce == `ChipDisable) begin
		inst <= `ZeroWord;
	end 
	else begin
	   inst <= inst_mem[addr[`InstMemNumLog2+1:2]];
	end
end

endmodule