`timescale 1ns / 1ps

module uart_tx_vlog 
  (
   input       i_Clock,           // master clock
   input       i_Tx_DV,           // data valid - set high to send byte
   input [7:0] i_Tx_Byte,         // byte to send
   output reg  o_Tx_Serial,       // UART serial TX wire
   output      o_Tx_Done,         // done signal, goes high for 2 clk cycles when finished sending
   output      o_Tx_Ready         // when high, UART TX is ready to send (not busy)
   );
  
  localparam s_IDLE         = 3'b000;
  localparam s_TX_START_BIT = 3'b001;
  localparam s_TX_DATA_BITS = 3'b010;
  localparam s_TX_STOP_BIT  = 3'b011;
  localparam s_CLEANUP      = 3'b100;
  localparam CLKS_PER_BIT   = 14'b10100010110000;   // hard coded to 9600 baud from the 100 MHz master clock
                                                    // i.e. 100 MHz / 9600 Hz = 10416 = 14'b10100010110000
   
  reg [2:0]    r_SM_Main     = 0;
  reg [13:0]    r_Clock_Count = 0;
  reg [2:0]    r_Bit_Index   = 0;
  reg [7:0]    r_Tx_Data     = 0;
  reg          r_Tx_Done     = 0;
  reg          r_Tx_Active   = 0;
     
  always @(posedge i_Clock)
    begin
       
      case (r_SM_Main)
        s_IDLE :
          begin
            o_Tx_Serial   <= 1'b1;         // Drive Line High for Idle
            r_Tx_Done     <= 1'b0;
            r_Clock_Count <= 0;
            r_Bit_Index   <= 0;
             
            if (i_Tx_DV == 1'b1)
              begin
                r_Tx_Active <= 1'b1;
                r_Tx_Data   <= i_Tx_Byte;
                r_SM_Main   <= s_TX_START_BIT;
              end
            else
              r_SM_Main <= s_IDLE;
          end // case: s_IDLE
         
         
        // Send out Start Bit. Start bit = 0
        s_TX_START_BIT :
          begin
            o_Tx_Serial <= 1'b0;
             
            // Wait CLKS_PER_BIT-1 clock cycles for start bit to finish
            if (r_Clock_Count < CLKS_PER_BIT-1)
              begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main     <= s_TX_START_BIT;
              end
            else
              begin
                r_Clock_Count <= 0;
                r_SM_Main     <= s_TX_DATA_BITS;
              end
          end // case: s_TX_START_BIT
         
         
        // Wait CLKS_PER_BIT-1 clock cycles for data bits to finish         
        s_TX_DATA_BITS :
          begin
            o_Tx_Serial <= r_Tx_Data[r_Bit_Index];
             
            if (r_Clock_Count < CLKS_PER_BIT-1)
              begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main     <= s_TX_DATA_BITS;
              end
            else
              begin
                r_Clock_Count <= 0;
                 
                // Check if we have sent out all bits
                if (r_Bit_Index < 7)
                  begin
                    r_Bit_Index <= r_Bit_Index + 1;
                    r_SM_Main   <= s_TX_DATA_BITS;
                  end
                else
                  begin
                    r_Bit_Index <= 0;
                    r_SM_Main   <= s_TX_STOP_BIT;
                  end
              end
          end // case: s_TX_DATA_BITS
         
         
        // Send out Stop bit.  Stop bit = 1
        s_TX_STOP_BIT :
          begin
            o_Tx_Serial <= 1'b1;
             
            // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
            if (r_Clock_Count < CLKS_PER_BIT-1)
              begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main     <= s_TX_STOP_BIT;
              end
            else
              begin
                r_Tx_Done     <= 1'b1;
                r_Clock_Count <= 0;
                r_SM_Main     <= s_CLEANUP;
                r_Tx_Active   <= 1'b0;
              end
          end // case: s_Tx_STOP_BIT
         
         
        // Stay here 1 clock
        s_CLEANUP :
          begin
            r_Tx_Done <= 1'b1;
            r_SM_Main <= s_IDLE;
          end
          
          
          
        default :
          r_SM_Main <= s_IDLE;
         
      endcase
    end
 
  assign o_Tx_Done   = r_Tx_Done;
  assign o_Tx_Ready = ~r_Tx_Active;  
endmodule