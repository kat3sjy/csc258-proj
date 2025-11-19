################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Kristen Wong, 1011088225
# Student 2: Kate Shen, 1011026934
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

GRID_WIDTH:
    .word 6                 # The game board is 6 units wide (0 to 5)
GRID_HEIGHT:
    .word 18                # The game board is 18 units high (0 to 17)
EMPTY_COLOR:
    .word 0x00000000        # The value used to represent an empty cell

# The main game board: 6 columns x 12 rows. Stores colour words (4 bytes each).
# Total size: 6 * 12 * 4 = 288 bytes. Initialized to all zeros (EMPTY_COLOR).
GAME_GRID:
    .space 432
GRID_SIZE:
    .word 108               # 6 * 18 = 108
MATCH_GRID:
    .byte 0:108

##############################################################################
# Mutable Data
##############################################################################
colours:
	.word   0xff0000
	.word   0xff8000
	.word   0xffff00
	.word   0x00ff00
	.word   0x0000ff
	.word   0xff00ff
	
borderColour:  .word 0xc0c0c0
currCol0:      .word 0                  # Top gem colour
currCol1:      .word 0                  # Middle gem colour 
currCol2:      .word 0                  # Bottom gem colour 
currColX:      .word 2                  # Column X position 
currColY:      .word 1                  # Column Y position 

x_msg:    .asciiz "currColX: "
y_msg:    .asciiz " currColY: "
newline:  .asciiz "\n"
debug_msg: .asciiz " match found"
debug_msg2: .asciiz " respondtoS"
debug_msg3: .asciiz "V_Collision_Found"
debug_msg4: .asciiz " checkKeyBoardInput"
debug_msg5: .asciiz "c"
debug_msg6: .asciiz "loop"
debug_msg7: .asciiz "V_RET:" 
debug_msg8: .asciiz "drawCurrCol"
lock_debug_msg: .asciiz "Locking: X="
y_label:
    .asciiz "Gem at (Y:"
x_label:
    .asciiz ", X:"
end_label:
    .asciiz ")\n"
color_label: .asciiz ") Color: "
debug_msg_resetY: .asciiz "Y reset to: "
debug_msg_currY: .asciiz "currColY IN drawCurrCol:"
debug_msg_lockY:  .asciiz "currColY before lock: "
debug_msg_loop: .asciiz "debug_msg_loop "
comma: .asciiz ", "
debug_msg_lock: .asciiz "Locking color: "
lock_start_msg: .asciiz "--- LOCK START ---\n"
lock_gem_msg:   .asciiz "Locking Gem: GridX="
lock_gridy_msg: .asciiz " GridY="
lock_color_msg: .asciiz " Color="
lock_addr_msg:  .asciiz " Addr="
debug_match_found_msg: .asciiz "--- MATCH FOUND. Grid state after clearing (before gravity): ---\n"
debug_match_check_str:  .asciiz "Checking cell ("
debug_comma_str:        .asciiz ", "
debug_color_str:        .asciiz "): Color "
debug_match_clear_str:  .asciiz "!!! MATCH FOUND and CLEARED starting at ("
debug_closing_str:      .asciiz ")\n"
debug_newline_str:      .asciiz "\n"
debug_before_gravity:   .asciiz "--- DEBUG: BEFORE Apply_Gravity ---\n"
    debug_after_gravity:    .asciiz "--- DEBUG: AFTER Apply_Gravity ---\n"
debug_gravity_base_str: .asciiz "--- Gravity Start: Base Addr ($s2) = 0x"
    debug_gravity_move_str: .asciiz "--- GRAVITY MOVE: "
    debug_Y_Src:            .asciiz "Y_Src="
    debug_Y_Dst:            .asciiz " Y_Dst="
    debug_SrcAddr:          .asciiz " SrcAddr=0x"
    debug_DstAddr:          .asciiz " DstAddr=0x"
    debug_gravity_start_str: .asciiz " gravity start"
    debug_rowcol_color_str: .asciiz " row color: "
    debug_gravity_end_str: .asciiz " gravity end"
    debug_gem2_xy_str:   .asciiz "DBG GEM 2 X,Y: ("
    debug_gem2_index_str: .asciiz "), Index (Byte Offset): "
    debug_gem2_addr_str:  .asciiz ", Address: 0x"
##############################################################################
# Code
##############################################################################
	
	.text
	.globl main

    # Run the game.
main:    
    # Initialize the game
    jal drawBorder
    jal drawCol
    
game_loop:       
    # 1a. Check if key has been pressed
    jal CheckKeyboardInput

    # 2. Check for Vertical Collision (Landing)
    jal Check_Vertical_Collision
    move $t0, $v0  # Save return value
    
    # move $v0, $t0  # Restore
    beq $v0, 1, Handle_Landing     # If collision, process landing and game events
    
    jal Draw_Game_Grid
    jal drawCurrCol
    
    # j game_loop
    b game_loop

Handle_Landing:    
    jal eraseCurrCol               # Erase the falling column from display
    jal Lock_Column_In_Place       # Transfer active column to permanent GAME_GRID
    
    # Redraw full grid now that column is locked
    jal Draw_Game_Grid
    
    # 5. Spawn new falling column immediately
    li $t0, 2           # starting X (column spawn)
    sw $t0, currColX
    li $t0, 1           # starting Y (top of screen)
    sw $t0, currColY

    # 6. Generate new column and draw it
    jal drawCol

    # 7. Draw full grid + new falling column
    jal Draw_Game_Grid
    jal drawCurrCol

    # 8. Check for game events
    lw $t0, currColY
    li $t1, 0
    blt $t0, $t1, Handle_GameOver
    
    
Match_And_Fall_Loop:

    # 9. Check for matches
    jal Check_For_Matches
    move $s0, $v0                    # $s0 = Was there a match?
    
    beq $s0, $zero, Skip_Gravity      

    # 10. Apply gravity (THE CORRUPTION SUSPECT)
    jal Apply_Gravity
    move $s1, $v0                    # $s1 = Did anything fall?
    
    # 11. If anything changed (match or fall), redraw and loop again
    or $t0, $s0, $s1
    beq $t0, $zero, Match_Loop_End   # If $s0|$s1 is 0, exit loop
    
    # We skip Draw_Game_Grid inside the loop to eliminate it as a suspect for now
    jal Draw_Game_Grid               
    j Match_And_Fall_Loop
    
Skip_Gravity:
    or $t0, $s0, $s1
    beq $t0, $zero, Match_Loop_End

Match_Loop_End:
    b game_loop

Handle_GameOver:
    # Placeholder for game over screen/message
    li $v0, 10
    syscall

print_grid_cell_for_debug:
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 0($sp)       # gridX
    sw $s1, 4($sp)       # startY
    sw $s2, 8($sp)       # loop counter

    move $s0, $a0        # s0 = gridX
    move $s1, $a1        # s1 = startY
    li $s2, 0            # loop counter (0..2)

PrintLoopDbg:
    beq $s2, 3, PrintDoneDbg

    # Compute Y = startY + s2
    add $s3, $s1, $s2     # s3 = current Y

    # index = Y * WIDTH + X
    lw $s4, GRID_WIDTH
    mul $s5, $s3, $s4
    add $s5, $s5, $s0     # s5 = index

    sll $s5, $s5, 2       # *4 for byte offset
    la $s6, GAME_GRID
    add $s6, $s6, $s5
    lw $s7, 0($s6)        # s7 = color

    # print y label
    li $v0, 4
    la $a0, y_label
    syscall
    li $v0, 1
    move $a0, $s3
    syscall

    # print x label
    li $v0, 4
    la $a0, x_label
    syscall
    li $v0, 1
    move $a0, $s0
    syscall

    # print color
    li $v0, 4
    la $a0, color_label
    syscall
    li $v0, 1
    move $a0, $s7
    syscall

    li $v0, 4
    la $a0, newline
    syscall

    addi $s2, $s2, 1
    j PrintLoopDbg

PrintDoneDbg:
    lw $s0, 0($sp)
    lw $s1, 4($sp)
    lw $s2, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra
	
CheckKeyboardInput:
    # program delay for 1 millisecond
    li $v0, 32
    li $a0, 1
    syscall
    
    lw $t0, ADDR_KBRD                  # $t0 = ADDR_KBRD
    lw $t1, 0($t0)                     # Check if key was pressed and stored in $t1
    
    beq $t1, 1, CheckKeyInput          # Check which key was pressed
    jr $ra 
    
CheckKeyInput:  
    lw $t2, 4($t0)
    beq $t2, 0x77, respondToW          # Check if the key W was pressed
    beq $t2, 0x61, respondToA          # Check if the key A was pressed
    beq $t2, 0x73, respondToS          # Check if the key S was pressed
    beq $t2, 0x64, respondToD          # Check if the key D was pressed
    beq $t2, 0x71, respondToQ          # Check if the key Q was pressed
    jr $ra

respondToW:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal shuffleCurrCol
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

respondToA:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal moveCurrLeft
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
respondToS:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal moveCurrDown
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
respondToD:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal moveCurrRight
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
respondToQ:
    li $v0, 10                         # Quit game
    syscall


    # jr $ra

drawCurrCol: 
    
    lw $t0, ADDR_DSPL
    lw $t1, currColX
    lw $t2, currColY
    
    lw $t3, currCol0
    sll $t4, $t2, 7
    sll $t5, $t1, 2
    add $t6, $t4, $t5
    add $t7, $t0, $t6
    sw $t3, 0($t7)
    
    lw $t3, currCol1
    addi $t8, $t2, 1
    sll $t4, $t8, 7
    add $t6, $t4, $t5
    add $t7, $t0, $t6
    sw $t3, 0($t7)

    lw $t3, currCol2
    addi $t8, $t2, 2
    sll $t4, $t8, 7
    add $t6, $t4, $t5
    add $t7, $t0, $t6
    sw $t3, 0($t7)

    jr $ra

# Function: eraseCurrCol
eraseCurrCol:
    
    lw $t0, ADDR_DSPL                  # Base display address
    lw $t1, currColX                   # $t1 = x of col
    lw $t2, currColY                   # $t2 = y of col

    sll $t4, $t2, 7                    # $t4 = Y * 128 - Logical shift left 7 to go down a row
    sll $t5, $t1, 2                    # $t5 = X * 4 - Logical shift left 2 to go right a column
    add $t6, $t4, $t5                  # $t6 = $t4 + $t5 - Total X and Y offset
    add $t7, $t0, $t6                  # $t7 = Address to erase
    sw $zero, 0($t7)                   # Erase by turning address to 0

    addi $t8, $t2, 1                   # currColY + 1 - moving from currCol0 to currCol1
    sll $t4, $t8, 7                    # Same as above 
    add $t6, $t4, $t5
    add $t7, $t0, $t6
    sw $zero, 0($t7)

    addi $t8, $t2, 2                   # $t8 = currColY + 2
    sll $t4, $t8, 7                    # Same as above 
    add $t6, $t4, $t5
    add $t7, $t0, $t6
    sw $zero, 0($t7)
    
    jr $ra

shuffleCurrCol:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)
    
    jal  eraseCurrCol                  # Erase current column 

    lw $t0, currCol0                   # $t0 = top gem
    lw $t1, currCol1                   # $t1 = middle gem
    lw $t2, currCol2                   # $t2 = bottom gem

    sw $t2, currCol0                   # bottom -> top
    sw $t0, currCol1                   # top -> middle
    sw $t1, currCol2                   # middle -> bottom

    jal drawCurrCol                    # Draw new column 
    
    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

moveCurrLeft: 
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)
    
    li $a0, -1                     # Check for moving Left (direction = -1)
    jal Check_Horizontal_Collision
    
    # If collision found ($v0 = 1), skip the move.
    beq $v0, 1, M_Left_End
    
    jal eraseCurrCol
    lw $t9, currColX
    addi $t9, $t9, -1
    sw $t9, currColX
    jal drawCurrCol
    
    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

M_Left_End:
    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

moveCurrDown:

    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)
    
    lw $t0, currColY
    addi $t1, $t0, 2        # future bottom gem Y = currColY + 3
    li   $t2, 17
    bge  $t1, $t2, M_Down_End   # if would go to Y=18 or more → stop
    
    jal Check_Vertical_Collision

    # move $v0, $t2     # ← RESTORE THE RETURN VALUE
    beq $v0, 1, M_Down_End
    
    jal eraseCurrCol
    
    lw   $t0, currColY      # load currColY value
    addi $t0, $t0, 1  
    # increment by 1
    sw   $t0, currColY      # save it back
    
    jal drawCurrCol
    
    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    
    jr $ra

M_Down_End:
    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

moveCurrRight:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)
    
    li $a0, 1                      # Check for moving Right (direction = 1)
    jal Check_Horizontal_Collision
    
    # If collision found ($v0 = 1), skip the move.
    beq $v0, 1, M_Right_End
    
    jal eraseCurrCol
    lw $t9, currColX
    addi $t9, $t9, 1
    sw $t9, currColX
    jal drawCurrCol
    
    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

M_Right_End:
    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# Function: drawBorder
# Arguments:         none
# Return Values:     none

drawBorder:
    lw $t0, ADDR_DSPL                   # $t0 = ADDR_DSPL
    lw $t1, borderColour                # $t1 = borderColour
    addi $t2, $t0, 0                    # $t2 = top left corner (starting point)
    addi $t3, $t0, 32                   # $t3 = horizontal destination
    addi $t4, $t0, 2304                 # $t4 = vertical destination
    
drawHBorders:
    beq $t2, $t3, drawHBordersEnd       # while ($t2 != $t3)
    sw $t1, 0($t2)                      # fill top border
    sw $t1, 2304($t2)                   # fill bottom border
    addi $t2, $t2, 4                    # $t2 += 4
    j drawHBorders
    drawHBordersEnd:

addi $t2, $t0, 128                      # change starting point

drawVBorders:
    beq $t2, $t4, drawVBordersEnd       # while ($t2 != $t4)
    sw $t1, 0($t2)                      # fill left border
    sw $t1, 28($t2)                     # fill right border
    addi $t2, $t2, 128                  # #t2 += 128
    j drawVBorders
    drawVBordersEnd:
        jr $ra
    
# Function: drawCol - draws initial column

drawCol:    
    addi $sp, $sp, -4                   # Make space on stack
    sw   $ra, 0($sp)                    # Save return address
    li $t4, 0

drawColLoop:    
    beq $t4, 3, drawColLoopEnd         # While $t4 != 3
    jal randomColour                   # Choose random colour
    move $t3, $v0                      # Store random colour in $t3 
    
    la $t5, currCol0                 # $t5 = Base register for activeCol0  
    sll $t6, $t4, 2                    # Logical shift left - $t6 = $t4 shifted left twice (for col0, col1, col2)
    add $t7, $t5, $t6                  # $t7 = activeCol0 + $t6 
    sw $t3, 0($t7)                     # Store colour in activeCol0, 1, 2 
    
    addi $t4, $t4, 1                   # $t4 += 1
    j drawColLoop
    
drawColLoopEnd:
    jal drawCurrCol
    lw   $ra, 0($sp)                   # Restore return address
    addi $sp, $sp, 4
    jr   $ra                           # Fixes all my problems

# Function: randomColour:
randomColour:
    addi $sp, $sp, -4          # Save register on stack
    sw $t0, 0($sp)
    
    li $v0, 42                         # System call to produce a random int 
    li $a0, 0                          # min = 0 
    li $a1, 6                          # max = 5 
    syscall
    
    move $t0, $a0                      # Store random number in $t0 
    
    la $t1, colours                    # $t1 = array of colours 
    mul $t0, $t0, 4                    # Offset of 4 
    add $t1, $t1, $t0                  # Choose colour based on random number 
    
    lw $v0, 0($t1)                     # Store colour in $v0 
    
    lw $t0, 0($sp)             # Restore register
    addi $sp, $sp, 4
    
    jr $ra
    
# Function: Draw_Game_Grid
# Renders all cells of the permanent GAME_GRID.
Draw_Game_Grid:    
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    lw $t0, ADDR_DSPL              # $t0 = Base address of the display
    la $t1, GAME_GRID              # $t1 = Base address of the game grid array
    lw $t2, GRID_WIDTH             # $t2 = 6 (Width)
    lw $t3, EMPTY_COLOR            # $t3 = 0 (Empty color)
    lw $t4, GRID_HEIGHT            # $t4 = 18 (Height)

    li $t5, 0                      # $t5 = Row counter (Y, 0 to 17)
    
GridRowLoop:
    beq $t5, $t4, GridDraw_End     # If Y == GRID_HEIGHT, done
    
    li $t6, 0                      # $t6 = Column counter (X, 0 to 5)
    
GridColLoop:
    beq $t6, $t2, Next_Grid_Row    # If X == GRID_WIDTH, next row

    # Calculate Array Index: Index = Y * W + X
    mul $t7, $t5, $t2              # Y * WIDTH
    add $t7, $t7, $t6              # $t7 = Index
    
    # Read Color from GAME_GRID
    sll $t8, $t7, 2                # Index * 4
    add $t8, $t1, $t8              # Address in GAME_GRID
    lw $t9, 0($t8)                 # $t9 = Color
    
    # Check if empty
    beq $t9, $t3, Next_Grid_Column
    
    
    
    # Calculate display address
    addi $t7, $t5, 1               # Display Y
    addi $t8, $t6, 1               # Display X
    sll $t7, $t7, 7                # * 128
    sll $t8, $t8, 2                # * 4
    add $t7, $t7, $t8
    add $t7, $t0, $t7
    sw $t9, 0($t7)

Next_Grid_Column:
    addi $t6, $t6, 1
    j GridColLoop

Next_Grid_Row:
    addi $t5, $t5, 1
    j GridRowLoop
    
GridDraw_End:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# Function: Check_Horizontal_Collision
# (Insert the full Check_Horizontal_Collision code provided previously here)
# Argument: $a0 = direction (-1 for Left, 1 for Right)
# Returns: $v0 = 1 if collision detected, 0 otherwise.
Check_Horizontal_Collision:
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)                  # ← ADD
    sw $s1, 4($sp)                  # ← ADD
    sw $s2, 0($sp)                  # ← ADD
    
    move $s0, $a0
    lw $s1, currColX
    lw $s2, currColY
    
    add $t0, $s1, $s0              # $t0 = proposed new X position

    # 1. Check for Wall Collision (X > 5 or X < 0)
    li $t9, 1
    blt $t0, $t9, H_Collision_Found     # If new X < 1, collision with left border
    li $t9, 7
    bge $t0, $t9, H_Collision_Found     # If new X >= 7, collision with right border

    addi $t0, $t0, -1
    
    # 2. Check for Gem Collision (at new X, for Y, Y+1, Y+2)
    la $t1, GAME_GRID
    lw $t2, GRID_WIDTH
    li $t3, 0                      # Loop counter (i = 0, 1, 2)

H_GemCheck_Loop:
    beq $t3, 3, H_No_Collision
    
    # Calculate Y-coordinate for this gem
    add $t4, $s2, $t3              # $t4 = Y + i (the row)
    
    # Skip check if gem is outside of the 12x6 grid (only affects top gem if currColY < 0)
    lw $t5, GRID_HEIGHT             # $t5 = 12
    blt $t4, $zero, H_Skip_Check   # If Y+i < 0, skip check
    bge $t4, $t5, H_Skip_Check     # If Y+i >= 12, skip check (GRID_HEIGHT is 12)

    # Calculate Grid Index: Index = (Y + i) * 6 + (new X)
    mul $t5, $t4, $t2
    add $t5, $t5, $t0              # $t5 = Index

    # Calculate memory address
    sll $t6, $t5, 2
    add $t7, $t1, $t6
    lw $t8, 0($t7)                 # $t8 = Color at [new X][Y+i]
    lw $t9, EMPTY_COLOR
    
    bne $t8, $t9, H_Collision_Found # If (Color != EMPTY), collision with a gem!

H_Skip_Check:
    addi $t3, $t3, 1               # Increment counter
    j H_GemCheck_Loop

H_No_Collision:
    li $v0, 0
    j H_End

H_Collision_Found:
    li $v0, 1

H_End:
    lw $s2, 0($sp)                  # ← ADD
    lw $s1, 4($sp)                  # ← ADD
    lw $s0, 8($sp)                  # ← ADD
    lw $ra, 12($sp)
    addi $sp, $sp, 16               # ← CHANGE
    jr $ra

Check_Vertical_Collision:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)      # gem index
    sw   $s1, 0($sp)      # temp for debug

    lw $t0, currColX       # X pos (display: 1-6)
    lw $t1, currColY       # Y pos (top gem) (display: 1-17)
    la $t2, GAME_GRID
    lw $t3, GRID_WIDTH     # 6
    lw $t4, GRID_HEIGHT    # 18
    lw $t9, EMPTY_COLOR

    li $v0, 0              # default: no collision

    # Loop over the 3 gems in the column
    li $s0, 0              # gem index (0..2)

V_Check_Loop:
    beq $s0, 3, V_No_Collision

    add $t5, $t1, $s0      # Y of current gem (display coordinates)

    # Check if gem is at the bottom of play area (Y = 17 in display coords)
    li $t6, 17
    bge $t5, $t6, V_Collision_Found
    
    # Skip if gem is above grid (negative Y)
    blt $t5, $zero, V_Skip_Gem

    addi $t6, $t5, 1       # check cell below (Y+1 in display coordinates)

    # If cell below is bottom of play area, collision
    li $t7, 17
    bge $t6, $t7, V_Collision_Found

    # Convert display coordinates to grid coordinates for grid access
    # Grid X = display X - 1 (because display X=1-6, grid X=0-5)
    # Grid Y = display Y - 1 (because display Y=1-17, grid Y=0-16)
    addi $a0, $t0, -1      # grid X
    addi $a1, $t6, -1      # grid Y (cell below)

    # Calculate index: idx = grid_Y * WIDTH + grid_X
    mul $t7, $a1, $t3      # grid_Y * 6
    add $t7, $t7, $a0      # + grid_X

    # Bounds check for grid access
    blt $t7, $zero, V_Skip_Gem
    li $t8, 108            # 18 rows * 6 cols = 108 max index
    bge $t7, $t8, V_Skip_Gem

    # Access memory
    sll $t7, $t7, 2        # * 4 bytes
    add $t7, $t2, $t7      # GAME_GRID address
    lw  $t8, 0($t7)        # Color at grid[grid_X][grid_Y]
    
    bne $t8, $t9, V_Collision_Found  # If not empty, collision!

V_Skip_Gem:
    addi $s0, $s0, 1
    j V_Check_Loop

V_Collision_Found:
    li $v0, 1

V_No_Collision:
    lw   $s1, 0($sp)
    lw   $s0, 4($sp)
    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra
    
Lock_Column_In_Place:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)
    sw   $s1, 0($sp)

    # Convert display coordinates to 0-indexed grid coordinates
    lw   $s0, currColX
    addi $s0, $s0, -1       # $s0 = grid X (0-indexed)
    lw   $s1, currColY
    addi $s1, $s1, -1       # $s1 = grid Y of top gem (0-indexed)

    # Load gem colors
    lw $s3, currCol0         # $s3 = top color
    lw $s4, currCol1         # $s4 = middle color
    lw $s5, currCol2         # $s5 = bottom color

    lw $s2, GRID_WIDTH       # $s2 = width (6)
    # The following variables are used inside the loop and don't need to be s-registers
    lw $t9, GRID_HEIGHT      # $t9 = height (18)
    la $t0, GAME_GRID        # $t0 = grid base address (&GAME_GRID)

    li $t2, 0                # $t2 = gem loop 0..2
LockLoop:
    beq $t2, 3, LockLoopEnd

    # Compute grid Y of this gem
    add $t5, $s1, $t2        # $t5 = grid Y of this gem
    blt $t5, $zero, Skip_Lock
    bge $t5, $t9, Skip_Lock

    # Select color
    li $t6, 0
    beq $t2, $t6, Use_Col0
    li $t6, 1
    beq $t2, $t6, Use_Col1
    li $t6, 2
    beq $t2, $t6, Use_Col2
    j Skip_Lock

Use_Col0:
    move $t4, $s3             # $t4 = color
    j Store_Lock
Use_Col1:
    move $t4, $s4
    j Store_Lock
Use_Col2:
    move $t4, $s5

Store_Lock:
    # Compute grid index and store
    mul $t7, $t5, $s2        # $t7 = Y * width
    add $t7, $t7, $s0        # $t7 = index (Y*W + X)
    sll $t8, $t7, 2          # $t8 = index * 4 bytes
    
    # Final memory address where the color should be written
    add $t8, $t0, $t8        # $t8 = &GAME_GRID + offset

    # Store the color at the calculated address
    sw  $t4, 0($t8)
    
Skip_Lock:
    addi $t2, $t2, 1
    j LockLoop

LockLoopEnd:
Lock_Done:
    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# ============================
# Apply_Gravity with Debugging
# ============================

Apply_Gravity:
    # Save $ra and all used $s registers
    addi $sp, $sp, -36
    sw $ra, 32($sp)
    sw $s0, 28($sp)
    sw $s1, 24($sp)
    sw $s2, 20($sp)
    sw $s3, 16($sp)
    sw $s4, 12($sp)
    sw $s5, 8($sp)
    sw $s6, 4($sp)
    
    # Setup initial registers
    li $s0, 0                   # moved_flag
    lw $s1, GRID_WIDTH          # WIDTH
    la $s2, GAME_GRID           # &GAME_GRID
    lw $s3, EMPTY_COLOR         # EMPTY_COLOR

    # --- DEBUG: Print initial grid ---
    li $v0, 4
    la $a0, debug_gravity_start_str
    syscall
    jal Print_Grid_Contents      # Custom routine to print full grid

    li $s4, 0                   # X = 0 (column loop)
ColLoop_Gravity:
    beq $s4, $s1, GravityEnd

    li $s6, -1                  # drop_target_Y
    lw $t0, GRID_HEIGHT
    addi $t0, $t0, -1
    move $s5, $t0               # Y = HEIGHT-1

RowLoop_Gravity:
    blt $s5, $zero, NextCol_Gravity

    # Compute index and addresses
    mul $t0, $s5, $s1           # t0 = Y*WIDTH
    add $t1, $t0, $s4           # Index
    sll $t2, $t1, 2
    add $t3, $s2, $t2           # &GAME_GRID[Y][X]
    lw $t4, 0($t3)              # Color at [Y][X]

    # --- DEBUG: Print current position and color ---
    li $v0, 4
    la $a0, debug_rowcol_color_str
    syscall
    li $v0, 1
    move $a0, $s4               # Column X
    syscall
    li $v0, 1
    move $a0, $s5               # Row Y
    syscall
    li $v0, 1
    move $a0, $t4               # Color
    syscall

    # If empty, update drop_target_Y
    beq $t4, $s3, GemIsEmpty

    # If colored gem and drop target exists, move it
    blt $s6, $zero, NextRow_Gravity

    # Compute destination index and address
    mul $t5, $s6, $s1
    add $t6, $t5, $s4           # Index_Dst
    sll $t7, $t6, 2
    add $t8, $s2, $t7           # &GAME_GRID[drop_target_Y][X]

    # --- DEBUG: Print move info ---
    li $v0, 4
    la $a0, debug_gravity_move_str
    syscall
    li $v0, 1
    move $a0, $s5               # Y source
    syscall
    li $v0, 1
    move $a0, $s6               # Y dest
    syscall
    li $v0, 1
    move $a0, $s4               # Column X
    syscall
    li $v0, 1
    move $a0, $t4               # Color
    syscall

    # Move gem
    sw $t4, 0($t8)              # dst = color
    sw $s3, 0($t3)              # src = EMPTY

    # --- DEBUG: Verify move ---
    lw $t9, 0($t8)
    li $v0, 1
    move $a0, $t9
    syscall
    lw $t9, 0($t3)
    li $v0, 1
    move $a0, $t9
    syscall

    li $s0, 1                   # Mark something moved
    move $s6, $s5               # Update drop_target_Y

    j NextRow_Gravity

GemIsEmpty:
    move $s6, $s5               # Update drop_target_Y
NextRow_Gravity:
    addi $s5, $s5, -1
    j RowLoop_Gravity

NextCol_Gravity:
    addi $s4, $s4, 1
    j ColLoop_Gravity

GravityEnd:
    move $v0, $s0               # Return moved_flag

    # --- DEBUG: Print final grid ---
    li $v0, 4
    la $a0, debug_gravity_end_str
    syscall
    jal Print_Grid_Contents

    # Restore registers
    lw $s6, 4($sp)
    lw $s5, 8($sp)
    lw $s4, 12($sp)
    lw $s3, 16($sp)
    lw $s2, 20($sp)
    lw $s1, 24($sp)
    lw $s0, 28($sp)
    lw $ra, 32($sp)
    addi $sp, $sp, 36
    jr $ra

# ----------------------------
# Print_Grid_Contents
# ----------------------------
# Prints the full GAME_GRID for debugging (Row-major order dump)
Print_Grid_Contents:
    # Save used $s registers ($s4 and $s5)
    addi $sp, $sp, -8  
    sw $s4, 4($sp)
    sw $s5, 0($sp)

    lw $t0, GRID_WIDTH             # $t0 = W (6)
    li $s5, 0                   # $s5 = Row Y (0)
PrintGrid_Rows:
    lw $t1, GRID_HEIGHT            # $t1 = H (18)
    bge $s5, $t1, PrintGrid_Done   # if Y >= H, finish printing
    
    li $s4, 0                   # $s4 = Column X (0)
PrintGrid_Cols:
    beq $s4, $t0, NextGrid_Row     # if X == W, go to next row
    
    # Calculate Index (Y * W + X) * 4
    mul $t2, $s5, $t0
    add $t2, $t2, $s4
    sll $t3, $t2, 2
    la $t4, GAME_GRID
    add $t5, $t4, $t3
    
    # Print gem color
    lw $a0, 0($t5)
    li $v0, 1
    syscall
    
    # Advance X and loop
    addi $s4, $s4, 1
    j PrintGrid_Cols
    
NextGrid_Row:
    # Print newline for formatting (optional, but helpful for single line dump)
    # li $v0, 4
    # la $a0, debug_newline_str
    # syscall 
    
    # Advance Y and loop
    addi $s5, $s5, 1
    j PrintGrid_Rows
    
PrintGrid_Done:
    # Print a final newline after the dump
    li $v0, 4
    la $a0, debug_newline_str
    syscall
    
    # Restore registers and stack
    lw $s5, 0($sp)
    lw $s4, 4($sp)
    addi $sp, $sp, 8
    
    jr $ra


# Function: Check_For_Matches
# Scan GAME_GRID for 3+ in a row (H, V, D). Clears the matches if found.
# Returns: $v0 = 1 if match found and cleared, 0 otherwise.
Check_For_Matches:
    
    # Save $ra and all used $s registers (9 registers * 4 bytes = 36 bytes)
    addi $sp, $sp, -36
    sw $ra, 32($sp)
    sw $s0, 28($sp) # $s0 = match_found_flag
    sw $s1, 24($sp) # $s1 = W (GRID_WIDTH = 6)
    lw $s2, GRID_HEIGHT             # $s2 = 18 (H)
    sw $s2, 20($sp)                 # Save H
    la $s3, GAME_GRID               # $s3 = &GAME_GRID
    sw $s3, 16($sp)
    lw $s4, EMPTY_COLOR             # $s4 = 0
    sw $s4, 12($sp)
    li $s5, 0                       # $s5 = Y loop counter (Start Y = 0)
    sw $s5, 8($sp)
    li $s6, 0                       # $s6 = X loop counter (Start X = 0)
    sw $s6, 4($sp)
    li $s7, 0                       # $s7 will hold Current X for Check_Direction
    sw $s7, 0($sp)

    # Setup core registers for main loop
    li $s0, 0                       # $s0 = match_found_flag = 0
    lw $s1, GRID_WIDTH              # $s1 = 6 (W)
    lw $s2, GRID_HEIGHT             # $s2 = 18 (H)
    la $s3, GAME_GRID               # $s3 = &GAME_GRID
    lw $s4, EMPTY_COLOR             # $s4 = 0
    li $s5, 0                       # $s5 = Y = 0

MatchYLoop:
    beq $s5, $s2, MatchLoopEnd      # if Y == 18, end outer loop
    li $s6, 0                       # $s6 = X = 0

MatchXLoop:
    beq $s6, $s1, NextY_Match       # if X == 6, end inner loop

    # Check if the starting gem is empty. If so, skip all checks for this (X,Y)
    # Index = Y * W + X
    mul $t0, $s5, $s1
    add $t1, $t0, $s6
    sll $t2, $t1, 2
    add $t3, $s3, $t2
    
    # checking if pixel is empty
    lw $t4, 0($t3)
    beq $t4, $s4, NextX_Match       # If Color is EMPTY, skip
    
    # --- DEBUG PRINT 1: Coordinates and Color ---
    # Save $t registers that syscalls clobber
    addi $sp, $sp, -4
    sw $t4, 0($sp)                  # Save current Color (C0)

    li $v0, 4
    la $a0, debug_match_check_str 
    syscall                         # Print "Checking cell ("
    
    li $v0, 1
    move $a0, $s6                   # $s6 = X
    syscall
    
    li $v0, 4
    la $a0, debug_comma_str         # Print ", "
    syscall
    
    li $v0, 1
    move $a0, $s5                   # $s5 = Y
    syscall
    
    li $v0, 4
    la $a0, debug_color_str         # Print "): Color "
    syscall
    
    li $v0, 1
    lw $a0, 0($sp)                  # Restore and print Color (C0)
    syscall

    li $v0, 4
    la $a0, debug_newline_str       # Print "\n"
    syscall
    
    lw $t4, 0($sp)                  # Restore $t4 (C0)
    addi $sp, $sp, 4                # Restore $sp
    # ------------------------------------------

    # Set up start X for Check_Direction
    move $s7, $s6                   # $s7 = Current X (save it once)
    
    # --- 1. Check Vertical (dx=0, dy=1). Only check if Y <= 15
    li $t0, 15
    bgt $s5, $t0, Skip_Check_Vertical    # If Y > 15, skip this check
    
    # Call Check_Direction for Vertical
    li $a0, 0                       # dX = 0
    li $a1, 1                       # dY = 1
    move $a2, $s5                   # $a2 = Current Y
    jal Check_Direction
    or $s0, $s0, $v0                 # Update match_found_flag
    
Skip_Check_Vertical:
    # --- 2. Check Horizontal (dx=1, dy=0). Only check if X <= 3
    li $t0, 3
    bgt $s7, $t0, Skip_Check_Horizontal  # If X > 3, skip this check
    
    # Call Check_Direction for Horizontal
    li $a0, 1                       # dX = 1
    li $a1, 0                       # dY = 0
    move $a2, $s5                   # $a2 = Current Y
    jal Check_Direction
    or $s0, $s0, $v0
    
Skip_Check_Horizontal:
    # --- 3. Check Diagonal Down-Right (dx=1, dy=1). Check if X <= 3 AND Y <= 15 (FIXED)
    li $t0, 3
    bgt $s7, $t0, Skip_Check_DR      # If X > 3, skip
    li $t1, 15                      # FIXED: Y limit is 15 (18 rows total)
    bgt $s5, $t1, Skip_Check_DR      # If Y > 15, skip
    
    # Call Check_Direction for Diagonal Down-Right
    li $a0, 1                       # dX = 1
    li $a1, 1                       # dY = 1
    move $a2, $s5                   # $a2 = Current Y
    jal Check_Direction
    or $s0, $s0, $v0
    
Skip_Check_DR:
    # --- 4. Check Diagonal Down-Left (dx=-1, dy=1). Check if X >= 2 AND Y <= 15 (FIXED)
    li $t0, 2
    blt $s7, $t0, Skip_Check_DL      # If X < 2, skip
    li $t1, 15                      # FIXED: Y limit is 15 (18 rows total)
    bgt $s5, $t1, Skip_Check_DL      # If Y > 15, skip
    
    # Call Check_Direction for Diagonal Down-Left
    li $a0, -1                      # dX = -1
    li $a1, 1                       # dY = 1
    move $a2, $s5                   # $a2 = Current Y
    jal Check_Direction
    or $s0, $s0, $v0
    
Skip_Check_DL:

NextX_Match:
    # Check if a match was found in this cell's checks.
    bnez $s0, Restart_Match_Scan
    addi $s6, $s6, 1                 # X++
    j MatchXLoop

NextY_Match:
    addi $s5, $s5, 1                 # Y++
    j MatchYLoop

Restart_Match_Scan:
    # Reset loop counters
    li $s5, 0                       # Y = 0
    li $s6, 0                       # X = 0
    li $s0, 0                       # Reset match flag
    j MatchYLoop                    # Go back to the start of the Y loop
    
MatchLoopEnd:
    move $v0, $s0                   # Return match_found_flag in $v0

    # Restore registers (Corrected: 36 bytes)
    lw $s7, 0($sp)
    lw $s6, 4($sp)
    lw $s5, 8($sp)
    lw $s4, 12($sp)
    lw $s3, 16($sp)
    lw $s2, 20($sp)
    lw $s1, 24($sp)
    lw $s0, 28($sp)
    lw $ra, 32($sp)
    addi $sp, $sp, 36               # <-- FIX: Must be 36 to match setup
    jr $ra
    
# Check_For_Matches:
    
    # # Save $ra and all used $s registers (9 registers * 4 bytes = 36 bytes)
    # addi $sp, $sp, -36
    # sw $ra, 32($sp)
    # sw $s0, 28($sp) # $s0 = match_found_flag
    # lw $s1, GRID_WIDTH             # $s1 = W (GRID_WIDTH = 6)
    # sw $s1, 24($sp)
    # lw $s2, GRID_HEIGHT            # $s2 = 18 (H)
    # sw $s2, 20($sp)                # Save H
    # la $s3, GAME_GRID              # $s3 = &GAME_GRID
    # sw $s3, 16($sp)
    # lw $s4, EMPTY_COLOR            # $s4 = 0
    # sw $s4, 12($sp)
    # li $s5, 0                      # $s5 = Y loop counter (Start Y = 0)
    # sw $s5, 8($sp)
    # li $s6, 0                      # $s6 = X loop counter (Start X = 0)
    # sw $s6, 4($sp)
    # li $s7, 0                      # $s7 will hold Current X for Check_Direction
    # sw $s7, 0($sp)

    # # Setup core registers for main loop
    # li $s0, 0                      # $s0 = match_found_flag = 0
    # lw $s1, GRID_WIDTH             # $s1 = 6 (W)
    # lw $s2, GRID_HEIGHT            # $s2 = 18 (H)
    # la $s3, GAME_GRID              # $s3 = &GAME_GRID
    # lw $s4, EMPTY_COLOR            # $s4 = 0
    # li $s5, 0                      # $s5 = Y = 0

# MatchYLoop:
    # beq $s5, $s2, MatchLoopEnd      # if Y == 18, end outer loop
    # li $s6, 0                      # $s6 = X = 0

# MatchXLoop:
    # beq $s6, $s1, NextY_Match       # if X == 6, end inner loop

    # # ... (Your logic for calculating address of (X,Y) and checking if empty) ...
    # mul $t0, $s5, $s1
    # add $t1, $t0, $s6
    # sll $t2, $t1, 2
    # add $t3, $s3, $t2
    # lw $t4, 0($t3)
    # beq $t4, $s4, NextX_Match       # If Color is EMPTY, skip

    # # --- DEBUG PRINT 1: Coordinates and Color ---
    # # ... (Your debug print logic remains here) ...
    # # ------------------------------------------

    # # Set up start X for Check_Direction
    # move $s7, $s6                   # $s7 = Current X (required input)
    
    # # --- 1. Check Vertical (dx=0, dy=1). Only check if Y <= 15
    # li $t0, 15
    # bgt $s5, $t0, Skip_Check_Vertical
    
    # # Call Check_Direction for Vertical
    # li $a0, 0                       # dX = 0
    # li $a1, 1                       # dY = 1
    # move $a2, $s5                   # $a2 = Current Y
    # jal Check_Direction
    # or $s0, $s0, $v0                 # Update match_found_flag
    
# Skip_Check_Vertical:
    # # --- 2. Check Horizontal (dx=1, dy=0). Only check if X <= 3
    # li $t0, 3
    # bgt $s7, $t0, Skip_Check_Horizontal
    
    # # Call Check_Direction for Horizontal
    # li $a0, 1                       # dX = 1
    # li $a1, 0                       # dY = 0
    # move $a2, $s5                   # $a2 = Current Y
    # jal Check_Direction
    # or $s0, $s0, $v0
    
# Skip_Check_Horizontal:
    # # --- 3. Check Diagonal Down-Right (dx=1, dy=1). Check if X <= 3 AND Y <= 15
    # li $t0, 3
    # bgt $s7, $t0, Skip_Check_DR
    # li $t1, 15
    # bgt $s5, $t1, Skip_Check_DR
    
    # # Call Check_Direction for Diagonal Down-Right
    # li $a0, 1                       # dX = 1
    # li $a1, 1                       # dY = 1
    # move $a2, $s5                   # $a2 = Current Y
    # jal Check_Direction
    # or $s0, $s0, $v0
    
# Skip_Check_DR:
    # # --- 4. Check Diagonal Down-Left (dx=-1, dy=1). Check if X >= 2 AND Y <= 15
    # li $t0, 2
    # blt $s7, $t0, Skip_Check_DL
    # li $t1, 15
    # bgt $s5, $t1, Skip_Check_DL
    
    # # Call Check_Direction for Diagonal Down-Left
    # li $a0, -1                      # dX = -1
    # li $a1, 1                       # dY = 1
    # move $a2, $s5                   # $a2 = Current Y
    # jal Check_Direction
    # or $s0, $s0, $v0
    
# Skip_Check_DL:

# NextX_Match:
    # # Check if a match was found in this cell's checks.
    # # Note: Immediate restart is a valid, but costly, strategy.
    # bnez $s0, Perform_Clear_And_Restart_Logic 
    # addi $s6, $s6, 1                 # X++
    # j MatchXLoop

# NextY_Match:
    # addi $s5, $s5, 1                 # Y++
    # j MatchYLoop

# MatchLoopEnd:
    # # If a match was found during the whole scan, proceed to clear it.
    # bnez $s0, Perform_Clear_And_Restart_Logic
    
    # # No matches found, return 0.
    # move $v0, $s0                   # Return match_found_flag (0)
    # j Check_Done

# Perform_Clear_And_Restart_Logic:
    # # 1. Clear all flagged matches (updates GAME_GRID and VRAM)
    # jal EraseMatches
    
    # # 2. Run Gravity (drops gems).
    # # You MUST have a working Gravity function for the game to progress.
    # jal Gravity
    
    # # 3. Restart the entire check process from (0, 0)
    # li $s5, 0                       # Y = 0
    # li $s6, 0                       # X = 0
    # li $s0, 0                       # Reset match flag for the new scan
    # j MatchYLoop                    # Go back to the start of the Y loop
    
# Check_Done:
    # # Restore registers (36 bytes)
    # lw $s7, 0($sp)
    # lw $s6, 4($sp)
    # lw $s5, 8($sp)
    # lw $s4, 12($sp)
    # lw $s3, 16($sp)
    # lw $s2, 20($sp)
    # lw $s1, 24($sp)
    # lw $s0, 28($sp)
    # lw $ra, 32($sp)
    # addi $sp, $sp, 36
    # jr $ra


# Function: Check_Direction
# Helper for Check_For_Matches. Checks for 3-in-a-row starting at ($s7, $s8) 
# in direction ($a0, $a1). Clears the gems if a match is found.
# Arguments: $a0 = dX, $a1 = dY
# Caller's $s7 = start X, $s8 = start Y
# Returns: $v0 = 1 if match cleared, 0 otherwise
# Function: Check_Direction
# Helper for Check_For_Matches. Checks for 3-in-a-row starting at ($s7, $a2) 
# in direction ($a0, $a1). Clears the gems if a match is found.
# Arguments: $a0 = dX, $a1 = dY, $a2 = start Y
# Caller's $s7 = start X
# Returns: $v0 = 1 if match cleared, 0 otherwise
# Check_Direction:    
    # # Save $ra and $s0 (newly used s-register)
    # addi $sp, $sp, -8            # Reserve 8 bytes
    # sw $ra, 4($sp)
    # sw $s0, 0($sp)               # Use $s0 to hold &GAME_GRID (safer)

    # li $v0, 0                    # Default return value: 0 (No match cleared)

    # # Setup constants/variables
    # lw $t0, GRID_WIDTH           # $t0 = W (6)
    # la $s0, GAME_GRID            # <-- FIX: Use $s0 for &GAME_GRID
    # lw $t2, EMPTY_COLOR          # $t2 = EMPTY (0)
    
    # # Store 3 addresses on the stack (3 * 4 = 12 bytes)
    # addi $sp, $sp, -12
    
    # move $t3, $s7                   # $t3 = X (start X)
    # move $t4, $a2                   # $t4 = Y (start Y)
    
    # # --- GEM 0: (X, Y) ---
    # # BOUNDS CHECK for Gem 0
    # blt $t3, $zero, DirEnd_NoMatch
    # bge $t3, $t0, DirEnd_NoMatch
    # blt $t4, $zero, DirEnd_NoMatch
    # lw $t9, GRID_HEIGHT             
    # bge $t4, $t9, DirEnd_NoMatch
    
    # mul $t6, $t4, $t0               # $t6 = Y * W
    # add $t6, $t6, $t3               # $t6 = Index 0
    # sll $t6, $t6, 2
    # add $t7, $s0, $t6               # $t7 = Address 0
    # lw $t8, 0($t7)                  # $t8 = Color 0 (C0)
    
    # sw $t7, 8($sp)                  # Store Address 0 at 8($sp)
    # move $t5, $t8                   # <--- FIX: Save C0's color to $t5 for safe comparison.
    
    # beq $t8, $t2, DirEnd_NoMatch    # If C0 is empty, no match possible.
    
    # # --- GEM 1: (X+dX, Y+dY) ---
    # add $t3, $t3, $a0               # X = X + dX
    # add $t4, $t4, $a1               # Y = Y + dY
    
    # # BOUNDS CHECK for Gem 1 (uses $t9 to temporarily hold dimensions)
    # blt $t3, $zero, DirEnd_NoMatch
    # lw $t9, GRID_WIDTH
    # bge $t3, $t9, DirEnd_NoMatch
    # blt $t4, $zero, DirEnd_NoMatch
    # lw $t9, GRID_HEIGHT
    # bge $t4, $t9, DirEnd_NoMatch
    
    # mul $t6, $t4, $t0               # $t6 = Y * W
    # add $t6, $t6, $t3               # $t6 = Index 1
    # sll $t6, $t6, 2
    # add $t7, $s0, $t6               # $t7 = Address 1
    # lw $t8, 0($t7)                  # $t8 = Color 1 (C1)
    # sw $t7, 4($sp)                  # Store Address 1 at 4($sp)
    
    # bne $t8, $t5, DirEnd_NoMatch    # <--- FIX: Compare C1 ($t8) with C0 ($t5)
    
    # # --- GEM 2: (X+2dX, Y+2dY) ---
    # add $t3, $t3, $a0               # X = X + dX
    # add $t4, $t4, $a1               # Y = Y + dY
    
    # # BOUNDS CHECK for Gem 2 (uses $t9 to temporarily hold dimensions)
    # blt $t3, $zero, DirEnd_NoMatch
    # lw $t9, GRID_WIDTH
    # bge $t3, $t9, DirEnd_NoMatch
    # blt $t4, $zero, DirEnd_NoMatch
    # lw $t9, GRID_HEIGHT
    # bge $t4, $t9, DirEnd_NoMatch
    
    # mul $t6, $t4, $t0               # $t6 = Y * W
    # add $t6, $t6, $t3               # $t6 = Index 2
    # sll $t6, $t6, 2
    # add $t7, $s0, $t6               # $t7 = Address 2
    # lw $t8, 0($t7)                  # $t8 = Color 2 (C2)
    # sw $t7, 0($sp)                  # Store Address 2 at 0($sp)
    
    # # Compare C2 with C0 (now in $t5)
    # bne $t8, $t5, DirEnd_NoMatch    # <--- FIX: Compare C2 ($t8) with C0 ($t5)
    
    # # --- DEBUG PRINT 2: Match CONFIRMED and CLEARED ---
    
    # # NOTE: $t3 is currently X+2dX, $t4 is Y+2dY. $s7 is START X, $a2 is START Y.
    # li $v0, 4
    # la $a0, debug_match_clear_str 
    # syscall                         # Print "!!! MATCH FOUND and CLEARED starting at ("
    
    # li $v0, 1
    # move $a0, $s7                   # Print START X
    # syscall
    
    # li $v0, 4
    # la $a0, debug_comma_str         # Print ", "
    # syscall
    
    # li $v0, 1
    # move $a0, $a2                   # Print START Y
    # syscall
    
    # li $v0, 4
    # la $a0, debug_closing_str       # Print ")\n"
    # syscall
    # # ------------------------------------------
    
    # # --- Match Found (C0 == C1 == C2 and C0 != EMPTY) ---
    # li $v0, 1                       # Set return value to 1
    
    # # Clear the three gems
    # lw $t0, 8($sp)                   # Address 0
    # sw $t2, 0($t0)                   # Clear Gem 0 (using $t2 = EMPTY_COLOR)
    
    # lw $t0, 4($sp)                   # Address 1
    # sw $t2, 0($t0)                   # Clear Gem 1
    
    # lw $t0, 0($sp)                   # Address 2
    # sw $t2, 0($t0)                   # Clear Gem 2

    # # --- CRITICAL DEBUG STEP ---
    # # Call Print_Grid_Contents immediately after clearing.
    # # If the output shows the ENTIRE grid is zeroed here, 
    # # the addresses saved on the stack (8($sp), 4($sp), 0($sp)) are wrong.
    # jal Print_Grid_Contents
    # # ---------------------------

# DirEnd_NoMatch:
    # # Cleanup stack for addresses (12 bytes)
    # addi $sp, $sp, 12               
    
    # # Restore registers (must match original saves)
    # lw $s0, 0($sp)               # Restore $s0
    # lw $ra, 4($sp)               # Restore $ra
    # addi $sp, $sp, 8             # Restore stack pointer
    # jr $ra

Check_Direction: 
    # Save $ra and used $s registers ($s0, $s1, $s2, $s3)
    addi $sp, $sp, -20             # Allocate 5 words (20 bytes)
    sw $ra, 16($sp)
    sw $s0, 12($sp)                # $s0 will hold &GAME_GRID
    sw $s1, 8($sp)                 # $s1 will hold Address 1
    sw $s2, 4($sp)                 # $s2 will hold Address 2
    sw $s3, 0($sp)                 # $s3 will hold Address 0

    li $v0, 0                      # Default return value: 0 (No match cleared)

    # Setup constants/variables
    lw $t0, GRID_WIDTH             # $t0 = W (6)
    la $s0, GAME_GRID              # $s0 = &GAME_GRID (FIXED BASE ADDRESS)
    lw $t2, EMPTY_COLOR            # $t2 = EMPTY (0)
    
    move $t3, $s7                  # $t3 = X (start X)
    move $t4, $a2                  # $t4 = Y (start Y)
    
    # --- GEM 0: (X, Y) ---
    # BOUNDS CHECK for Gem 0
    blt $t3, $zero, DirEnd_NoMatch
    bge $t3, $t0, DirEnd_NoMatch
    blt $t4, $zero, DirEnd_NoMatch
    lw $t9, GRID_HEIGHT            
    bge $t4, $t9, DirEnd_NoMatch
    
    mul $t6, $t4, $t0              # $t6 = Y * W
    add $t6, $t6, $t3              # $t6 = Index 0
    sll $t6, $t6, 2
    add $s3, $s0, $t6              # $s3 = Address 0 (NEW: Saved in $s3)
    lw $t8, 0($s3)                 # $t8 = Color 0 (C0)
    
    move $t5, $t8                  # Save C0's color to $t5 for comparison.
    
    beq $t8, $t2, DirEnd_NoMatch   # If C0 is empty, no match possible.
    
    # --- GEM 1: (X+dX, Y+dY) ---
    add $t3, $t3, $a0              # X = X + dX
    add $t4, $t4, $a1              # Y = Y + dY
    
    # BOUNDS CHECK for Gem 1
    blt $t3, $zero, DirEnd_NoMatch
    lw $t9, GRID_WIDTH
    bge $t3, $t9, DirEnd_NoMatch
    blt $t4, $zero, DirEnd_NoMatch
    lw $t9, GRID_HEIGHT
    bge $t4, $t9, DirEnd_NoMatch
    
    mul $t6, $t4, $t0              # $t6 = Y * W
    add $t6, $t6, $t3              # $t6 = Index 1
    sll $t6, $t6, 2
    add $s1, $s0, $t6              # $s1 = Address 1 (NEW: Saved in $s1)
    lw $t8, 0($s1)                 # $t8 = Color 1 (C1)
    
    bne $t8, $t5, DirEnd_NoMatch   # Compare C1 ($t8) with C0 ($t5)
    
    # --- GEM 2: (X+2dX, Y+2dY) ---
    add $t3, $t3, $a0              # X = X + dX
    add $t4, $t4, $a1              # Y = Y + dY
    
    # BOUNDS CHECK for Gem 2
    blt $t3, $zero, DirEnd_NoMatch
    lw $t9, GRID_WIDTH
    bge $t3, $t9, DirEnd_NoMatch
    blt $t4, $zero, DirEnd_NoMatch
    lw $t9, GRID_HEIGHT
    bge $t4, $t9, DirEnd_NoMatch
    
    mul $t6, $t4, $t0              # $t6 = Y * W
    add $t6, $t6, $t3              # $t6 = Index 2
    sll $t6, $t6, 2
    add $s2, $s0, $t6              # $s2 = Address 2 (NEW: Saved in $s2)
    lw $t8, 0($s2)                 # $t8 = Color 2 (C2)
    
    # Compare C2 with C0 (now in $t5)
    bne $t8, $t5, DirEnd_NoMatch   # Compare C2 ($t8) with C0 ($t5)

    # ------------------------------------------------------------------
    # --- CRITICAL DEBUG BLOCK: Gem 2 Address Check ---
    # Save transient registers before syscalls clobber them
    addi $sp, $sp, -12
    sw $t3, 8($sp)  # Save X
    sw $t4, 4($sp)  # Save Y
    sw $t6, 0($sp)  # Save Index (Byte Offset)

    # Print "DBG GEM 2 X,Y: ("
    li $v0, 4
    la $a0, debug_gem2_xy_str 
    syscall

    # Print X ($t3)
    li $v0, 1
    move $a0, $t3 
    syscall

    # Print ", "
    li $v0, 4
    la $a0, debug_comma_str
    syscall

    # Print Y ($t4)
    li $v0, 1
    move $a0, $t4 
    syscall

    # Print "), Index (Byte Offset): "
    li $v0, 4
    la $a0, debug_gem2_index_str
    syscall

    # Print Index (byte offset, $t6)
    li $v0, 1
    move $a0, $t6
    syscall

    # Print ", Address: 0x"
    li $v0, 4
    la $a0, debug_gem2_addr_str
    syscall

    # Print Address ($s2) in hex
    li $v0, 34 
    move $a0, $s2
    syscall
    
    # Print "\n"
    li $v0, 4
    la $a0, debug_newline_str
    syscall

    # Restore registers and stack
    lw $t6, 0($sp)
    lw $t4, 4($sp)
    lw $t3, 8($sp)
    addi $sp, $sp, 12
    # --- END CRITICAL DEBUG BLOCK ---
    # ------------------------------------------------------------------
    
    # --- DEBUG PRINT: Match CONFIRMED and CLEARED ---
    
    li $v0, 4
    la $a0, debug_match_clear_str  
    syscall                         # Print "!!! MATCH FOUND and CLEARED starting at ("
    
    li $v0, 1
    move $a0, $s7                   # Print START X
    syscall
    
    li $v0, 4
    la $a0, debug_comma_str         
    syscall
    
    li $v0, 1
    move $a0, $a2                   # Print START Y
    syscall
    
    li $v0, 4
    la $a0, debug_closing_str       
    syscall
    
    # --- Match Found (C0 == C1 == C2 and C0 != EMPTY) ---
    li $v0, 1                      # Set return value to 1
    
    # Clear the three gems using dedicated $s registers
    sw $t2, 0($s3)                 # Clear Gem 0
    sw $t2, 0($s1)                 # Clear Gem 1
    sw $t2, 0($s2)                 # Clear Gem 2

    # CRITICAL DEBUG STEP: Check grid state immediately after clearing.
    jal Print_Grid_Contents 

DirEnd_NoMatch:
    # Restore registers and stack (5 words / 20 bytes)
    lw $s3, 0($sp)                 # Restore $s3
    lw $s2, 4($sp)                 # Restore $s2
    lw $s1, 8($sp)                 # Restore $s1
    lw $s0, 12($sp)                # Restore $s0
    lw $ra, 16($sp)                # Restore $ra
    addi $sp, $sp, 20              # Restore stack pointer
    jr $ra

# Check_Direction: 
    # # Save $ra and used $s registers ($s0, $s1, $s2, $s3)
    # addi $sp, $sp, -20             # Allocate 5 words (20 bytes)
    # sw $ra, 16($sp)
    # sw $s0, 12($sp)                # $s0 will hold &GAME_GRID
    # sw $s1, 8($sp)                 # $s1 will hold Address 1
    # sw $s2, 4($sp)                 # $s2 will hold Address 2
    # sw $s3, 0($sp)                 # $s3 will hold Address 0

    # li $v0, 0                      # Default return value: 0 (No match found)

    # # Setup constants/variables
    # lw $t0, GRID_WIDTH             # $t0 = W (6)
    # la $s0, GAME_GRID              # $s0 = &GAME_GRID (FIXED BASE ADDRESS)
    # lw $t2, EMPTY_COLOR            # $t2 = EMPTY (0)
    
    # move $t3, $s7                  # $t3 = X (start X, passed in $s7)
    # move $t4, $a2                  # $t4 = Y (start Y, passed in $a2)
    
    # # --- GEM 0: (X, Y) ---
    # # BOUNDS CHECK for Gem 0
    # blt $t3, $zero, DirEnd_NoMatch
    # bge $t3, $t0, DirEnd_NoMatch
    # blt $t4, $zero, DirEnd_NoMatch
    # lw $t9, GRID_HEIGHT            
    # bge $t4, $t9, DirEnd_NoMatch
    
    # mul $t6, $t4, $t0              # $t6 = Y * W
    # add $t6, $t6, $t3              # $t6 = Index 0 (Cell Index)
    # sll $t6, $t6, 2
    # add $s3, $s0, $t6              # $s3 = Address 0 
    # lw $t8, 0($s3)                 # $t8 = Color 0 (C0)
    
    # move $t5, $t8                  # Save C0's color to $t5 for comparison.
    
    # beq $t8, $t2, DirEnd_NoMatch   # If C0 is empty, no match possible.
    
    # # --- GEM 1: (X+dX, Y+dY) ---
    # add $t3, $t3, $a0              # X = X + dX
    # add $t4, $t4, $a1              # Y = Y + dY
    
    # # BOUNDS CHECK for Gem 1
    # blt $t3, $zero, DirEnd_NoMatch
    # lw $t9, GRID_WIDTH
    # bge $t3, $t9, DirEnd_NoMatch
    # blt $t4, $zero, DirEnd_NoMatch
    # lw $t9, GRID_HEIGHT
    # bge $t4, $t9, DirEnd_NoMatch
    
    # mul $t6, $t4, $t0              # $t6 = Y * W
    # add $t6, $t6, $t3              # $t6 = Index 1
    # sll $t6, $t6, 2
    # add $s1, $s0, $t6              # $s1 = Address 1 
    # lw $t8, 0($s1)                 # $t8 = Color 1 (C1)
    
    # bne $t8, $t5, DirEnd_NoMatch   # Compare C1 ($t8) with C0 ($t5)
    
    # # --- GEM 2: (X+2dX, Y+2dY) ---
    # add $t3, $t3, $a0              # X = X + dX
    # add $t4, $t4, $a1              # Y = Y + dY
    
    # # BOUNDS CHECK for Gem 2
    # blt $t3, $zero, DirEnd_NoMatch
    # lw $t9, GRID_WIDTH
    # bge $t3, $t9, DirEnd_NoMatch
    # blt $t4, $zero, DirEnd_NoMatch
    # lw $t9, GRID_HEIGHT
    # bge $t4, $t9, DirEnd_NoMatch
    
    # mul $t6, $t4, $t0              # $t6 = Y * W
    # add $t6, $t6, $t3              # $t6 = Index 2
    # sll $t6, $t6, 2
    # add $s2, $s0, $t6              # $s2 = Address 2 
    # lw $t8, 0($s2)                 # $t8 = Color 2 (C2)
    
    # # Compare C2 with C0 (now in $t5)
    # bne $t8, $t5, DirEnd_NoMatch   # Compare C2 ($t8) with C0 ($t5)
    
    # # --- MATCH CONFIRMED: FLAG THE GEMS ---
    
    # li $v0, 1                      # Set return value to 1 (Match Found)
    
    # la $t9, MATCH_GRID             # $t9 = &MATCH_GRID base address
    # lb $t8, MATCH_FLAG_VAL         # $t8 = 1 (Flag value)

    # # --- Address to Index Conversion: (Addr - &GAME_GRID) / 4 + &MATCH_GRID ---
    
    # # Flag Gem 0 (Address in $s3)
    # sub $t7, $s3, $s0              # $t7 = Byte Offset in GAME_GRID
    # sra $t7, $t7, 2                # $t7 = Index 0 (Byte Offset / 4)
    # add $t7, $t9, $t7              # $t7 = Address 0 in MATCH_GRID
    # sb $t8, 0($t7)                 # Store the flag (1)

    # # Flag Gem 1 (Address in $s1)
    # sub $t7, $s1, $s0              # $t7 = Byte Offset
    # sra $t7, $t7, 2                # $t7 = Index 1
    # add $t7, $t9, $t7              # $t7 = Address 1 in MATCH_GRID
    # sb $t8, 0($t7)                 # Store the flag (1)

    # # Flag Gem 2 (Address in $s2)
    # sub $t7, $s2, $s0              # $t7 = Byte Offset
    # sra $t7, $t7, 2                # $t7 = Index 2
    # add $t7, $t9, $t7              # $t7 = Address 2 in MATCH_GRID
    # sb $t8, 0($t7)                 # Store the flag (1)
    
    # # --- DEBUG PRINT: Match FLAGGED ---
    # # (You can reuse your debug prints here, just update the string label)
    # li $v0, 4
    # la $a0, debug_match_clear_str  # Print "!!! MATCH FLAGGED at ("
    # syscall                        
    
    # # ... (Print coordinates as before) ...
    
# DirEnd_NoMatch:
    # # Restore registers and stack (5 words / 20 bytes)
    # lw $s3, 0($sp)                 # Restore $s3
    # lw $s2, 4($sp)                 # Restore $s2
    # lw $s1, 8($sp)                 # Restore $s1
    # lw $s0, 12($sp)                # Restore $s0
    # lw $ra, 16($sp)                # Restore $ra
    # addi $sp, $sp, 20              # Restore stack pointer
    # jr $ra
# # ---------------------------------------------------------
# # Draw_Empty_Cell
# # Inputs: $a0 = Cell Index (0 to 107)
# # ---------------------------------------------------------
# Draw_Empty_Cell:
    # # Save $ra and $t registers
    # addi $sp, $sp, -8
    # sw $ra, 4($sp)
    # sw $t0, 0($sp)
    
    # # 1. Calculate the VRAM Address
    # sll $t0, $a0, 2               # $t0 = Index * 4 (byte offset)
    
    # lw $t1, ADDR_DSPL             # $t1 = 0x10008000 (VRAM Base Address)
    # add $t0, $t1, $t0             # $t0 = VRAM Address
    
    # # 2. Get the empty color
    # lw $t1, EMPTY_COLOR           # $t1 = 0x00000000 (Empty Color)
    
    # # 3. Write the color to VRAM to update the screen
    # sw $t1, 0($t0)                # VRAM[Index] = EMPTY_COLOR
    
    # # Restore registers
    # lw $t0, 0($sp)
    # lw $ra, 4($sp)
    # addi $sp, $sp, 8
    
    # jr $ra
    
# # ---------------------------------------------------------
# # EraseMatches
# # Clears all cells marked in MATCH_GRID and resets the flags.
# # ---------------------------------------------------------
# EraseMatches:
    # addi $sp, $sp, -16             # Save $ra, $s0, $s1, $s2
    # sw $ra, 12($sp)
    # sw $s0, 8($sp)                 # $s0 = &MATCH_GRID Pointer
    # sw $s1, 4($sp)                 # $s1 = &GAME_GRID Pointer
    # sw $s2, 0($sp)                 # $s2 = Loop Index

    # la $s0, MATCH_GRID             # $s0 = pointer to MATCH_GRID (byte array)
    # la $s1, GAME_GRID              # $s1 = pointer to GAME_GRID (word array)
    # lw $t2, EMPTY_COLOR            # $t2 = EMPTY_COLOR (for logical grid)
    # lw $t4, GRID_SIZE              # $t4 = GRID_SIZE (108)

    # li $s2, 0                      # Index = 0

# EraseLoop:
    # beq $s2, $t4, EraseDone        # if Index == GRID_SIZE, exit

    # # 1. Read the flag from the MATCH_GRID
    # lb $t5, 0($s0)                 # $t5 = MATCH_GRID[Index]
    # beq $t5, $zero, SkipErase      # if 0 (not flagged) → skip

    # # 2. Clear the gem in the logical GAME_GRID 
    # sw $t2, 0($s1)                 

    # # 3. Clear the gem on the screen (VRAM)
    # move $a0, $s2                   # $a0 = Index (0 to 107)
    # jal Draw_Empty_Cell             
    
    # # 4. Clear the match flag
    # sb $zero, 0($s0)

# SkipErase:
    # # ADVANCE POINTERS AND INDEX
    # addi $s0, $s0, 1               # advance MATCH_GRID pointer by 1 BYTE
    # addi $s1, $s1, 4               # advance GAME_GRID pointer by 4 BYTES (a word)
    # addi $s2, $s2, 1               # Index++
    # j EraseLoop

# EraseDone:
    # # Print the grid to confirm clearing (optional)
    # # jal Print_Grid_Contents 
    
    # # Restore registers
    # lw $s2, 0($sp)
    # lw $s1, 4($sp)
    # lw $s0, 8($sp)
    # lw $ra, 12($sp)
    # addi $sp, $sp, 16
    # jr $ra

# Function to print the entire game grid
# Print_Grid_Contents:
    # li $v0, 1
    # lw $a0, GRID_WIDTH
    # syscall 
    
    # addi $sp, $sp, -28          # Adjusted stack size to save s4, s5, s6 (7 registers * 4 bytes = 28 bytes)
    # sw $ra, 24($sp)             
    # sw $s0, 20($sp)   # Y counter
    # sw $s1, 16($sp)   # X counter 
    # sw $s2, 12($sp)   # grid base
    # sw $s3, 8($sp)    # temp
    # sw $s4, 4($sp)    # GRID_WIDTH
    # sw $s5, 0($sp)    # GRID_HEIGHT
    # # Note: $s6 is used inside the loop, but not saved/restored by your original code, so we won't change that practice here.
    
    # la $s2, GAME_GRID
    # lw $s4, GRID_WIDTH
    # lw $s5, GRID_HEIGHT
    
    # li $s0, 0         # Y = 0
    
# Print_Grid_Y_Loop:
    # beq $s0, $s5, Print_Grid_Done
    
    # # Print row number
    # li $v0, 4
    # la $a0, y_label
    # syscall
    # li $v0, 1
    # move $a0, $s0
    # syscall
    # li $v0, 4
    # la $a0, x_label
    # syscall
    
    # li $s1, 0         # X = 0
    
# Print_Grid_X_Loop:
    # beq $s1, $s4, Print_Grid_Next_Row
    
    # # Calculate index and get color
    # mul $s3, $s0, $s4       # $s3 = Y * width
    # add $s3, $s3, $s1       # $s3 = index (Y*W + X)
    # sll $s3, $s3, 2         # $s3 = index * 4 bytes (offset)
    # add $s3, $s2, $s3       # $s3 = &GAME_GRID + offset (Final Address)
    
    # # --- DEBUG START: Print X, Y, and Address before loading ---
    
    # # Print "DBG_READ: GridX=" (reusing lock_gem_msg)
    # li $v0, 4
    # la $a0, lock_gem_msg    
    # syscall
    # li $v0, 1
    # move $a0, $s1           # Print Grid X ($s1)
    # syscall
    
    # # Print " GridY=" (reusing lock_gridy_msg)
    # li $v0, 4
    # la $a0, lock_gridy_msg
    # syscall
    # li $v0, 1
    # move $a0, $s0           # Print Grid Y ($s0)
    # syscall

    # # Print " Addr=" (reusing lock_addr_msg)
    # li $v0, 4
    # la $a0, lock_addr_msg
    # syscall
    # li $v0, 1
    # move $a0, $s3           # Print Memory Address ($s3)
    # syscall

    # # Read the color word
    # lw $s6, 0($s3)          # $s6 = color
    
    # # Print " Color=" (reusing lock_color_msg)
    # li $v0, 4
    # la $a0, lock_color_msg 
    # syscall
    # li $v0, 1
    # move $a0, $s6           # Print Color ($s6)
    # syscall
    
    # # Print "\n"
    # li $v0, 4
    # la $a0, newline         
    # syscall
    # # --- DEBUG END ---
    
    # # Print color value
    # li $v0, 1
    # move $a0, $s6
    # syscall
    
    # # Print space
    # li $v0, 11
    # li $a0, 32
    # syscall
    
    # addi $s1, $s1, 1
    # j Print_Grid_X_Loop

# Print_Grid_Next_Row:
    # # Newline
    # li $v0, 11
    # li $a0, 10
    # syscall
    
    # addi $s0, $s0, 1
    # j Print_Grid_Y_Loop

# Print_Grid_Done:
    # # Restore registers (must match new stack size)
    # lw $s5, 0($sp)
    # lw $s4, 4($sp)
    # lw $s3, 8($sp)
    # lw $s2, 12($sp)
    # lw $s1, 16($sp)
    # lw $s0, 20($sp)
    # lw $ra, 24($sp)
    # addi $sp, $sp, 28
    # jr $ra