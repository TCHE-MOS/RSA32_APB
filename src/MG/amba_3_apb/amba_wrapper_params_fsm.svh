    parameter logic [5:0] IDLE        = 6'b000000,
                          LOAD_MSG    = 6'b000001,
                          GAP_MSG_EXP = 6'b000010,
                          LOAD_EXP    = 6'b000100,
                          GAP_EXP_MOD = 6'b001000,
                          LOAD_MOD    = 6'b010000,
                          WAIT_DONE   = 6'b100000;