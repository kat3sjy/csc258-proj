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

newline:  .asciiz "\n"
debug_msg_resetY: .asciiz "yo "
comma: .asciiz ", "
space: .asciiz " "
debug_match_clear_str:  .asciiz "!!! MATCH FOUND and CLEARED starting at ("
    debug_after_match: .asciiz "after matched"
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
    move $s0, $v0      
    
    # debugging if match is found
    move $t9, $v0
    li $v0, 1
    move $a0, $s0
    syscall
    li $v0, 4
    la $a0, debug_msg_resetY
    syscall
    move $v0, $t9
    
    beq $s0, $zero, Skip_Gravity      

    jal Apply_Gravity
    move $s1, $v0                   

    or $t0, $s0, $s1
    beq $t0, $zero, Match_Loop_End   # If $s0|$s1 is 0, exit loop
    
    # jal Print_Grid_Contents
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
    jal Draw_Game_Grid

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
    # jal Draw_Game_Grid
    
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
    # jal Draw_Game_Grid
    
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
    # jal Draw_Game_Grid
    
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
    addi $t3, $t4, -1
    beq $t5, $t3, GridDraw_End     # If Y == GRID_HEIGHT, done
    
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
    
    # # Check if empty
    # beq $t9, $t3, Next_Grid_Column
    
    # # Calculate display address
    # addi $t7, $t5, 1               # Display Y
    # addi $t8, $t6, 1               # Display X
    # sll $t7, $t7, 7                # * 128
    # sll $t8, $t8, 2                # * 4
    # add $t7, $t7, $t8
    # add $t7, $t0, $t7
    # sw $t9, 0($t7)
    
    addi $t7, $t5, 1               # $t7 = Display Y ($t5 + 1)
    addi $t8, $t6, 1               # $t8 = Display X ($t6 + 1)
    sll $t7, $t7, 7                # Display Y * 128
    sll $t8, $t8, 2                # Display X * 4
    add $t7, $t7, $t8              # Row offset + Column offset
    add $t7, $t0, $t7              # $t7 = Final Display Address
    
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
    lw $s2, 0($sp)                 
    lw $s1, 4($sp)                  
    lw $s0, 8($sp)                  
    lw $ra, 12($sp)
    addi $sp, $sp, 16               
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
    li $t6, 18
    bge $t5, $t6, V_Collision_Found
    
    # Skip if gem is above grid (negative Y)
    blt $t5, $zero, V_Skip_Gem

    addi $t6, $t5, 1       # check cell below (Y+1 in display coordinates)

    # If cell below is bottom of play area, collision
    li $t7, 18
    bge $t6, $t7, V_Collision_Found
    
    # checking for collision with gem in grid

    # Convert display coordinates to grid coordinates for grid access
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
    
    bne $t8, $t9, V_Collision_Found  # If not empty, collision

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

    # loading grid data
    lw $s2, GRID_WIDTH       # $s2 = width (6)
    lw $t9, GRID_HEIGHT      # $t9 = height (18)
    la $t0, GAME_GRID        # $t0 = grid base address (&GAME_GRID)

    li $t2, 0                # $t2 = gem loop 0..2
LockLoop:
    beq $t2, 3, LockLoopEnd

    # Compute grid Y of this gem
    add $t5, $s1, $t2        # $t5 = grid Y of this gem (+ loop index)
    blt $t5, $zero, Skip_Lock  # bounds check
    bge $t5, $t9, Skip_Lock    # bounds check

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
    lw $t9, GRID_HEIGHT         # HEIGHT
    
    li $s4, 0                   # X = 0 (column loop)
    
ColLoop_Gravity:
    beq $s4, $s1, GravityEnd
    
    # Scan ENTIRE column from BOTTOM to TOP
    # Track write_pos (where next gem should go)
    li $s6, 16                  # write_pos = 16 (actual bottom row)
    li $s5, 16           # read_pos = HEIGHT-1 (start at bottom)
    
RowLoop_Gravity:
    blt $s5, $zero, NextCol_Gravity
    
    # Read from read_pos
    mul $t0, $s5, $s1
    add $t1, $t0, $s4
    sll $t2, $t1, 2
    add $t3, $s2, $t2           # &GAME_GRID[read_pos][X]
    lw $t4, 0($t3)              # gem at read_pos
    
    # If empty, just move to next
    beq $t4, $s3, NextRead
    
    # Found a gem - write it to write_pos
    # Calculate write address
    mul $t5, $s6, $s1
    add $t6, $t5, $s4
    sll $t7, $t6, 2
    add $t8, $s2, $t7           # &GAME_GRID[write_pos][X]
    
    # If read_pos == write_pos, gem doesn't move
    beq $s5, $s6, GemInPlace
    
    # Move gem from read_pos to write_pos
    sw $t4, 0($t8)              # Write to write_pos
    sw $s3, 0($t3)              # Clear read_pos
    li $s0, 1                   # Set moved_flag
    
GemInPlace:
    # After handling a gem, move write_pos up
    addi $s6, $s6, -1
    
NextRead:
    # Move read_pos up
    addi $s5, $s5, -1
    j RowLoop_Gravity
    
NextCol_Gravity:
    addi $s4, $s4, 1
    j ColLoop_Gravity
    
GravityEnd:
    move $v0, $s0               # Return moved_flag
    
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

# Prints the full GAME_GRID for debugging (Row-major order dump)
Print_Grid_Contents:
    # Save used $s registers ($s4 and $s5)
    addi $sp, $sp, -8  
    sw $s4, 4($sp)
    sw $s5, 0($sp)

    lw $t0, GRID_WIDTH             # $t0 = W (6)
    li $s5, 0                   # $s5 = Row Y (0)
PrintGrid_Rows:
    lw $t1, GRID_HEIGHT             # $t1 = H (18)
    add $t1, $t1, -1                # playing grid height is 17
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
    
    lw $t6, 0($t5)              # $t6 = Load the color/value from memory (GAME_GRID[Y][X])
    
    # Print the integer value (color)
    li $v0, 1                   # Syscall code for Print Integer
    move $a0, $t6               # Set argument to the loaded color value
    syscall
    
    # Print a space/separator
    li $v0, 4                   # Syscall code for Print String
    la $a0, space     # (Assuming 'debug_space_str' is defined as " ")
    syscall
    
    # Advance X and loop
    addi $s4, $s4, 1
    j PrintGrid_Cols
    
NextGrid_Row:
    # Print a newline at the end of the row 
    li $v0, 4
    la $a0, newline 
    syscall
    
    # Advance Y and loop
    addi $s5, $s5, 1
    j PrintGrid_Rows
    
PrintGrid_Done:
    # Print a final newline after the dump
    li $v0, 4
    la $a0, newline
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
    sw $s0, 28($sp)                 # $s0 = match_found_flag (1 for found, 0 otherwise)
    sw $s1, 24($sp)                 # $s1 = W (GRID_WIDTH = 6)
    lw $s2, GRID_HEIGHT             # $s2 = 18 (Height)
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
    
    # storing first column's color to fix overwrite issue
    addi $sp, $sp, -4
    sw $t4, 0($sp)                  # Save current Color (C0)
    
    lw $t4, 0($sp)                  # Restore $t4 (C0)
    addi $sp, $sp, 4                # Restore $sp

    # Set up start X for Check_Direction
    move $s7, $s6                   # $s7 = Current X (save it once)
    
    li $t0, 15
    bgt $s5, $t0, Skip_Check_Vertical    # If Y > 15, skip this check
    
    # Call Check_Direction for Vertical
    li $a0, 0                       # dX = 0
    li $a1, 1                       # dY = 1
    move $a2, $s5                   # $a2 = Current Y
    jal Check_Direction
    
    or $s0, $s0, $v0                 # Update match_found_flag
    
Skip_Check_Vertical:
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
    li $t1, 15                      # Y limit is 15 (18 rows total)
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
    li $t1, 15                      # Y limit is 15 (18 rows total)
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
    # bnez $s0, Restart_Match_Scan
    addi $s6, $s6, 1                 # X++ if no match found
    j MatchXLoop

NextY_Match:
    addi $s5, $s5, 1                 # Y++ if no match found
    j MatchYLoop

Restart_Match_Scan:
    # Reset loop counters
    li $s5, 0                       # Y = 0
    li $s6, 0                       # X = 0
    # li $s0, 0                       # Reset match flag
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
    addi $sp, $sp, 36            
    jr $ra

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
    add $s1, $s0, $t6              # $s1 = Address 1 (Saved in $s1)
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
    add $s2, $s0, $t6              # $s2 = Address 2 (Saved in $s2)
    lw $t8, 0($s2)                 # $t8 = Color 2 (C2)
    
    # Compare C2 with C0 (now in $t5)
    bne $t8, $t5, DirEnd_NoMatch   # Compare C2 ($t8) with C0 ($t5)
MatchFound:
    addi $sp, $sp, -12
    sw $t3, 8($sp)  # Save X
    sw $t4, 4($sp)  # Save Y
    sw $t6, 0($sp)  # Save Index (Byte Offset)
    
    # --- DEBUG PRINT: Match CONFIRMED and CLEARED ---
    move $t9, $v0   # save match result
    li $v0, 4
    la $a0, debug_match_clear_str  
    syscall                         # Print "!!! MATCH FOUND and CLEARED starting at ("
    move $v0, $t9  # save match result
    
    move $t9, $v0   # save match result
    li $v0, 1
    move $a0, $s7                   # Print START X
    syscall
    move $v0, $t9   # save match result
    
    move $t9, $v0   # save match result
    li $v0, 4
    la $a0, comma         
    syscall
    move $v0, $t9
    
    move $t9, $v0   # save match result
    li $v0, 1
    move $a0, $a2                   # Print START Y
    syscall
    move $v0, $t9
    
    move $t9, $v0   # save match result
    li $v0, 4
    la $a0, debug_closing_str       
    syscall
    move $v0, $t9
    
    # Clear the three gems using dedicated $s registers
    sw $t2, 0($s3)                 # Clear Gem 0
    sw $t2, 0($s1)                 # Clear Gem 1
    sw $t2, 0($s2)                 # Clear Gem 2

    # Restore the 12 bytes allocated for temp registers ($t3, $t4, $t6)
    move $t9, $v0 
    # jal Print_Grid_Contents 
    move $v0, $t9 
    
    addi $sp, $sp, 12
    
    li $v0, 1 
    
    # debugging
    move $t9, $v0
    li $v0, 4
    la $a0, debug_after_match
    syscall
    move $v0, $t9
    

    li $v0, 1          # <-- Set return value to 1 LAST
    j CD_Return        # <-- Jump to unified return

DirEnd_NoMatch:
    li $v0, 0
   
CD_Return:
    # restore all registers
    lw $s3, 0($sp)
    lw $s2, 4($sp)
    lw $s1, 8($sp)
    lw $s0, 12($sp)
    lw $ra, 16($sp)
    addi $sp, $sp, 20
    jr $ra
