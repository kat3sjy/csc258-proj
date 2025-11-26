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
	.word   0xff0000                  # red 
	.word   0xff8000                  # orange 
	.word   0xffff00                  # yellow 
	.word   0x00ff00                  # green 
	.word   0x0000ff                  # blue 
	.word   0xff00ff                  # purple 

score:          .word 0              # Current player score
chain_level:    .word 0              # Current chain multiplier (0 = no chain)
score_color:    .word 0xffffff       # White color for score display

# Digit patterns for 5x7 pixel font (0-9)
# Each digit is 5 pixels wide, 7 pixels tall
# 1 = pixel on, 0 = pixel off (stored as rows)
digit_0: .byte 0b111, 0b101, 0b101, 0b101, 0b111
digit_1: .byte 0b010, 0b110, 0b010, 0b010, 0b111
digit_2: .byte 0b111, 0b001, 0b111, 0b100, 0b111
digit_3: .byte 0b111, 0b001, 0b111, 0b001, 0b111
digit_4: .byte 0b101, 0b101, 0b111, 0b001, 0b001
digit_5: .byte 0b111, 0b100, 0b111, 0b001, 0b111
digit_6: .byte 0b111, 0b100, 0b111, 0b101, 0b111
digit_7: .byte 0b111, 0b001, 0b001, 0b001, 0b001
digit_8: .byte 0b111, 0b101, 0b111, 0b101, 0b111
digit_9: .byte 0b111, 0b101, 0b111, 0b001, 0b111

digit_table: .word digit_0, digit_1, digit_2, digit_3, digit_4, digit_5, digit_6, digit_7, digit_8, digit_9

difficulty_level:       .word 0             # 0=Easy, 1=Medium, 2=Hard
difficulty_selected:    .word 0             # 0=not selected, 1=selected

# Difficulty settings (initial gravity_interval values)
easy_interval:      .word 700000            # Slower (easier)
medium_interval:    .word 400000            # Normal
hard_interval:      .word 100000            # Faster (harder)

# Difficulty settings (gravity speed increase parameters)
easy_increase:      .word 15                # Speed up every 15 drops
medium_increase:    .word 10                # Speed up every 10 drops
hard_increase:      .word 7                 # Speed up every 7 drops

easy_decrement:     .word 40000             # Smaller speed increments
medium_decrement:   .word 50000             # Normal speed increments
hard_decrement:     .word 70000             # Larger speed increments

easy_min:           .word 200000            # Slower minimum speed
medium_min:         .word 150000            # Normal minimum speed
hard_min:           .word 100000            # Faster minimum speed

.align 2

gameOver_colour:    .word 0xffffff      # White
	
borderColour:  .word 0xc0c0c0
currCol0:      .word 0                  # Top gem colour
currCol1:      .word 0                  # Middle gem colour 
currCol2:      .word 0                  # Bottom gem colour 
currColX:      .word 2                  # Column X position 
currColY:      .word 1                  # Column Y position 

nextCol0:           .word 0             # Preview top gem colour
nextCol1:           .word 0             # Preview middle gem colour
nextCol2:           .word 0             # Preview bottom gem colour
nextColX:           .word 9             # X coord for preview col
nextColY:           .word 2             # Y coord for preview col

gravity_timer:      .word 0             # ms since last automatic drop
gravity_interval:   .word 500000        # interval between each drop
gravity_elapsed:    .word 0             # counts number of automatic drops
gravity_increase:   .word 10            # threshold number of automatic drops before speed up
gravity_min:        .word 150000        # smallest interval between each drop (fastest gravity speed)
gravity_decrement:  .word 50000         # gravity interval decrease per speed up

##############################################################################
# Code  
##############################################################################
	
	.text
	.globl main

    # Run the game.
main:    
    # Show difficulty selection screen
    jal showDifficultyScreen
    jal selectDifficulty
    jal applyDifficultySettings
    jal clearDisplay
    
    # Initialize the game
    jal drawBorder                  # Draw game border
    jal drawCol                     # Draw initial column
    lw $t0, nextCol0                # $t0 = preview column
    sw $t0, currCol0                # $t0 = current column
    lw $t0, nextCol1
    sw $t0, currCol1
    lw $t0, nextCol2
    sw $t0, currCol2
    li $t0, 2
    sw $t0, currColX
    li $t0, 1
    sw $t0, currColY
    jal drawCurrCol
    jal drawCol
    
game_loop:       
    # Check if key has been pressed
    jal CheckKeyboardInput

    # Gravity
    lw $t0, gravity_timer                   # $t0 = gravity_timer
    addi $t0, $t0, 1                        # $t0 += 1
    sw $t0, gravity_timer
    lw $t1, gravity_interval                # $t1 = gravity_intervak
    blt $t0, $t1, Skip_Gravity              # if $t0 < $t1, skip gravity loop
    
    lw $t6, gravity_elapsed                 # $t6 = gravity_elapsed
    addi $t6, $t6, 1                        # $t6 += 1
    sw $t6, gravity_elapsed

    lw $t7, gravity_increase               # $t7 = gravity_increase
    blt $t6, $t7, Skip_TimeSpeedup         # if $t6 < $t7, skip speedup

    # Time to level up: decrease gravity_interval and reset elapsed counter
    lw $t2, gravity_interval               # $t2 = gravity_interval
    lw $t3, gravity_decrement              # $t3 = gravity_decrement
    sub $t4, $t2, $t3                      # $t4 = $t2 - $t3
    lw $t5, gravity_min                    # $t5 = gravity_min
    blt $t4, $t5, SetIntervalMinTime       # if $t4 < $t5, set interval minimum

    sw $t4, gravity_interval              
    j ResetElapsed
    
SetIntervalMinTime:
    sw $t5, gravity_interval                # reset gravity_interval

ResetElapsed:
    sw $zero, gravity_elapsed               # reset gravity elapsed time to 0

Skip_TimeSpeedup:
    jal Check_Vertical_Collision            # check vertical collision
    beq $v0, 1, Handle_Landing              # if $v0 = 1, land piece
    
    jal moveCurrDown                        # automatic drop
    sw $zero, gravity_timer                 # reset gravity timer to 0

    # 2. Check for Vertical Collision (Landing)
    jal Check_Vertical_Collision
    move $t0, $v0  # Save return value
    
    beq $v0, 1, Handle_Landing     # If collision, process landing and game events
    
    jal Draw_Game_Grid
    jal drawCurrCol
    
    # Sleep for 16 ms
    li $v0, 32
    li $a0, 16
    syscall
    
    b game_loop

Handle_Landing:    
    jal eraseCurrCol               # Erase the falling column from display
    jal Lock_Column_In_Place       # Transfer active column to permanent GAME_GRID
    
    # Redraw full grid now that column is locked
    jal Draw_Game_Grid
    
    # 8. Check for game events
    lw $t0, currColY
    li $t1, 2
    blt $t0, $t1, Handle_GameOver
    
    lw $t0, nextCol0              
    sw $t0, currCol0
    lw $t0, nextCol1
    sw $t0, currCol1
    lw $t0, nextCol2
    sw $t0, currCol2

    li $t0, 2                       # starting X coord
    sw $t0, currColX
    li $t0, 1                       # starting Y coord
    sw $t0, currColY
    sw $zero, gravity_timer         # set gravity_timer to 0

    jal drawCol
    jal Draw_Game_Grid
    jal drawCurrCol
    
Match_And_Fall_Loop:
    # Check for matches
    jal Check_For_Matches
    move $s0, $v0      
    
    beq $s0, $zero, Skip_Gravity

    jal Apply_Gravity
    move $s1, $v0
    
    # Redraw everything 
    jal Draw_Game_Grid
    
    or $t0, $s0, $s1
    beq $t0, $zero, Match_Loop_End
    j Match_And_Fall_Loop
    
Skip_Gravity:
    or $t0, $s0, $s1
    beq $t0, $zero, Match_Loop_End

Match_Loop_End:
    jal Reset_Chain
    b game_loop
	
CheckKeyboardInput:
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
    beq $t2, 0x70, respondToP          # Check if the key P was pressed 
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

respondToP:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    
    jal pauseRoutine
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

pauseRoutine:
    addi $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)
    lw $t0, ADDR_DSPL                   # $t0 = ADDR_DSPL
    lw $t1, borderColour                # pause overlay colour (same as border)  
    
    # Left rectangle positions
    li $t2, 5                           # Starting Y coord
    li $t3, 13                          # Ending Y coord
    li $t4, 12                          # Starting X coord
    li $t5, 14                          # Ending X coord

pauseRoutineLeftRow:
    beq $t2, $t3, pauseRoutineLeftRowEnd
    sll $t6, $t2, 7                     # left row = y * 128
    move $t7, $t4                       # x counter

pauseRoutineLeftCol:
    beq $t7, $t5, pauseRoutineLeftColEnd
    sll $t8, $t7, 2                     # x * 4
    add $t9, $t6, $t8                   # left col + x * 4
    add $t9, $t0, $t9                   # final addr = ADDR_DSPL + offset
    sw $t1, 0($t9)                      # draw pixel
    addi $t7, $t7, 1
    j pauseRoutineLeftCol

pauseRoutineLeftColEnd:
    addi $t2, $t2, 1
    j pauseRoutineLeftRow

pauseRoutineLeftRowEnd:
    # Right rectangle positions
    li $t2, 5                         # Starting Y coord
    li $t3, 13                        # Ending Y coord
    li $t4, 16                        # Starting X coord
    li $t5, 18                        # Ending X coord

pauseRoutineRightRow:
    beq $t2, $t3, pauseRoutineRightRowEnd
    sll $t6, $t2, 7                    # $t6 = $t2 * 128
    move $t7, $t4

pauseRoutineRightCol:
    beq $t7, $t5, pauseRoutineRightColEnd       # while ($t7 (current col index) != $t5 (end col)), pauseRoutineRightColEnd
    sll $t8, $t7, 2                             # $t8 = $t7 (column index) * 4
    add $t9, $t6, $t8                           # $t9 = $t6 (row) + $t8 (col offset)
    add $t9, $t0, $t9                           # $t9 = $t0 + $t9, so $t9 is final address for right col
    sw $t1, 0($t9)                              # draw pixel
    addi $t7, $t7, 1                            # $t7 += 1 to move to next column
    j pauseRoutineRightCol

pauseRoutineRightColEnd:
    addi $t2, $t2, 1
    j pauseRoutineRightRow

pauseRoutineRightRowEnd:
    j pauseRoutineOverlayEnd
    
pauseRoutineOverlayEnd:
    lw $t9, ADDR_KBRD
    
pauseRoutineStart:
    lw $t0, 0($t9)                              # t0 = 1 if key is pressed
    beq $t0, $zero, pauseRoutineStartDone       # if $t0 = 0, pauseRoutineStartDone
    j pauseRoutineStart
pauseRoutineStartDone:

pauseRoutineWait:
    li $v0, 32                                  # sleep 100 ms
    li $a0, 100
    syscall

    lw $t0, 0($t9)                              # $t0 = 1 if pressed
    beq $t0, 1, pauseRoutineGotKey
    j pauseRoutineWait
    
pauseRoutineGotKey:
    lw $t1, 4($t9)                              # get ascii code
    li $t2, 0x70                                # Check if P was pressed
    beq $t1, $t2, pauseRoutineCheck             # if $t1 = $t2, commence unpause
    j pauseRoutineWait
pauseRoutineCheck:

pauseRoutineEnd:
    lw $t0, 0($t9)
    bne $t0, $zero, pauseRoutineEnd
    lw $s0, ADDR_DSPL                           # $s0 = ADDR_DSPL
    li $t1, 0                                   # $t1 = 0 (no colour)
    li $t2, 4                                   # starting y 
    li $t3, 14                                  # ending y   
    li $t4, 6                                   # starting x 
    li $t5, 26                                  # ending x   

clearPauseRow:
    beq $t2, $t3, clearPauseDone
    sll $t6, $t2, 7                             # row = y * 128
    move $t7, $t4                     

clearPauseCol:
    beq $t7, $t5, clearPauseNextRow
    sll $t8, $t7, 2                        # x * 4
    add $t9, $t6, $t8                      # row + x * 4
    add $t9, $s0, $t9                      # final address = ADDR_DSPL + offset
    sw $t1, 0($t9)                         # clear pixel
    addi $t7, $t7, 1
    j clearPauseCol

clearPauseNextRow:
    addi $t2, $t2, 1
    j clearPauseRow

clearPauseDone:
    jal Draw_Game_Grid                     # Redraw game state
    jal drawCurrCol
    # jal  Draw_Score
    jal drawBorder
    
    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra

drawCurrCol: 
    lw $t0, ADDR_DSPL                   # $t0 = ADDR_DSPL
    lw $t1, currColX
    lw $t2, currColY
    
    lw $t3, currCol0                    # draw top gem
    sll $t4, $t2, 7
    sll $t5, $t1, 2
    add $t6, $t4, $t5
    add $t7, $t0, $t6
    sw $t3, 0($t7)
    
    lw $t3, currCol1                    # draw middle gem
    addi $t8, $t2, 1    
    sll $t4, $t8, 7
    add $t6, $t4, $t5
    add $t7, $t0, $t6
    sw $t3, 0($t7)

    lw $t3, currCol2                    # draw bottom gem
    addi $t8, $t2, 2
    sll $t4, $t8, 7
    add $t6, $t4, $t5
    add $t7, $t0, $t6
    sw $t3, 0($t7)
    
    lw $t1, nextColX                    # preview X coord
    lw $t2, nextColY                    # preview Y coord

    lw $t3, nextCol0                    
    sll $t4, $t2, 7
    sll $t5, $t1, 2
    add $t6, $t4, $t5
    add $t7, $t0, $t6
    sw $t3, 0($t7)                      # draw next col top gem preview

    lw $t3, nextCol1
    addi $t8, $t2, 1
    sll $t4, $t8, 7
    add $t6, $t4, $t5
    add $t7, $t0, $t6
    sw  $t3, 0($t7)                     # draw next col middle gem preview

    lw $t3, nextCol2
    addi $t8, $t2, 2
    sll $t4, $t8, 7
    add $t6, $t4, $t5
    add $t7, $t0, $t6
    sw $t3, 0($t7)                      # draw next col bottom gem preview

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
    
    jal eraseCurrCol                   # Erase current column 
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
    
    li $a0, -1                          # Check for moving Left (direction = -1)
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
    addi $t1, $t0, 2                    # future bottom gem Y = currColY + 3
    li $t2, 17
    bge $t1, $t2, M_Down_End            # if $t1 >= $t2, M_Down_End
    
    jal Check_Vertical_Collision

    beq $v0, 1, M_Down_End
    
    jal eraseCurrCol
    
    lw $t0, currColY                    # load currColY value
    addi $t0, $t0, 1  
    # increment by 1
    sw   $t0, currColY                  # save it back
    
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
    
    li $a0, 1                           # Check for moving Right (direction = 1)
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
    sw $ra, 0($sp)                    # Save return address
    li $t4, 0

drawColLoop:    
    beq $t4, 3, drawColLoopEnd         # While $t4 != 3
    jal randomColour                   # Choose random colour
    move $t3, $v0                      # Store random colour in $t3 
    
    la $t5, nextCol0                 # $t5 = Base register for activeCol0  
    sll $t6, $t4, 2                    # Logical shift left - $t6 = $t4 shifted left twice (for col0, col1, col2)
    add $t7, $t5, $t6                  # $t7 = activeCol0 + $t6 
    sw $t3, 0($t7)                     # Store colour in nextCol0, 1, 2 
    
    addi $t4, $t4, 1                   # $t4 += 1
    j drawColLoop
    
drawColLoopEnd:
    jal drawCurrCol
    lw $ra, 0($sp)                   # Restore return address
    addi $sp, $sp, 4
    jr $ra                           # Fixes all my problems
    
# Function: randomColour
randomColour:
    addi $sp, $sp, -4                  # Save register on stack
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
    
    lw $t0, 0($sp)                     # Restore register
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
# Argument: $a0 = direction (-1 for Left, 1 for Right)
# Returns: $v0 = 1 if collision detected, 0 otherwise.
Check_Horizontal_Collision:
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)                
    sw $s1, 4($sp)                 
    sw $s2, 0($sp)                  
    
    move $s0, $a0
    lw $s1, currColX        # display X (1..6)
    addi $s1, $s1, -1       # convert to grid X (0..5)
    lw $s2, currColY
    
    add $t0, $s1, $s0              # $t0 = proposed new X position

    # Check for Wall Collision (X > 5 or X < 0)
    blt $t0, $zero, H_Collision_Found     # If new X < 1, collision with left border
    lw $t9, GRID_WIDTH
    bge $t0, $t9, H_Collision_Found     # If new X >= 7, collision with right border
    
    # Check for Gem Collision (at new X, for Y, Y+1, Y+2)
    la $t1, GAME_GRID
    lw $t2, GRID_WIDTH
    li $t3, 0                      # Loop counter (i = 0, 1, 2)

H_GemCheck_Loop:
    beq $t3, 3, H_No_Collision
    
    # Calculate Y-coordinate for this gem
    add $t4, $s2, $t3              # $t4 = Y + i (the row)
    
    # Skip check if gem is outside of the grid
    lw $t5, GRID_HEIGHT            
    blt $t4, $zero, H_Skip_Check  
    bge $t4, $t5, H_Skip_Check    

    # Calculate Grid Index: Index = (Y + i) * 6 + (new X)
    mul $t5, $t4, $t2
    add $t5, $t5, $t0          

    # Calculate memory address
    sll $t6, $t5, 2
    add $t7, $t1, $t6
    lw $t8, 0($t7)                
    lw $t9, EMPTY_COLOR
    
    bne $t8, $t9, H_Collision_Found # If (Color != EMPTY), collision with a gem

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
    sw $ra, 8($sp)
    sw $s0, 4($sp)     
    sw $s1, 0($sp)      

    lw $t0, currColX                    # X pos (display: 1-6)
    lw $t1, currColY                    # Y pos (top gem) (display: 1-17)
    la $t2, GAME_GRID
    lw $t3, GRID_WIDTH
    lw $t4, GRID_HEIGHT
    lw $t9, EMPTY_COLOR

    li $v0, 0                           # default: no collision

    # Loop over the 3 gems in the column
    li $s0, 0

V_Check_Loop:
    beq $s0, 3, V_No_Collision

    add $t5, $t1, $s0                   # Y of current gem (display coordinates)

    # Check if gem is at the bottom of play area (Y = 17 in display coords)
    li $t6, 18
    bge $t5, $t6, V_Collision_Found
    
    # Skip if gem is above grid (negative Y)
    blt $t5, $zero, V_Skip_Gem

    addi $t6, $t5, 1                    # check cell below (Y+1 in display coordinates)

    # If cell below is bottom of play area, collision
    li $t7, 18
    bge $t6, $t7, V_Collision_Found

    # Convert display coordinates to grid coordinates for grid access
    addi $a0, $t0, -1                   # grid X
    addi $a1, $t6, -1                   # grid Y (cell below)

    # Calculate index: index = grid_Y * width + grid_X
    mul $t7, $a1, $t3                   # grid_Y * 6
    add $t7, $t7, $a0                   # + grid_X

    # Bounds check for grid access
    blt $t7, $zero, V_Skip_Gem
    li $t8, 108            
    bge $t7, $t8, V_Skip_Gem

    # Access memory
    sll $t7, $t7, 2                     # * 4 bytes
    add $t7, $t2, $t7                   # GAME_GRID address
    lw $t8, 0($t7)                      # Color at grid[grid_X][grid_Y]
    
    bne $t8, $t9, V_Collision_Found  # If not empty, collision

V_Skip_Gem:
    addi $s0, $s0, 1
    j V_Check_Loop

V_Collision_Found:
    li $v0, 1

V_No_Collision:
    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra
    
Lock_Column_In_Place:
    addi $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)

    # Convert display coordinates to 0-indexed grid coordinates
    lw $s0, currColX
    addi $s0, $s0, -1                   # $s0 = grid X (0-indexed)
    lw $s1, currColY
    addi $s1, $s1, -1                   # $s1 = grid Y of top gem (0-indexed)

    # Load gem colors
    lw $s3, currCol0                    # $s3 = top color
    lw $s4, currCol1                    # $s4 = middle color
    lw $s5, currCol2                    # $s5 = bottom color

    # loading grid data
    lw $s2, GRID_WIDTH                  # $s2 = width (6)
    lw $t9, GRID_HEIGHT                 # $t9 = height (18)
    la $t0, GAME_GRID                   # $t0 = grid base address (&GAME_GRID)

    li $t2, 0                           # $t2 = gem loop 0-2
LockLoop:
    beq $t2, 3, LockLoopEnd

    # Compute grid Y of this gem
    add $t5, $s1, $t2                   # $t5 = grid Y of this gem (+ loop index)
    blt $t5, $zero, Skip_Lock           # bounds check
    bge $t5, $t9, Skip_Lock             # bounds check

    # Select color
    li $t6, 0
    beq $t2, $t6, Use_Col0
    li $t6, 1
    beq $t2, $t6, Use_Col1
    li $t6, 2
    beq $t2, $t6, Use_Col2
    j Skip_Lock

Use_Col0:
    move $t4, $s3            
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
    sw $t4, 0($t8)
    
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
    
    # Scanning column from bottom to top
    li $s6, 16                  # write_pos = 16 (bottom row)
    li $s5, 16                  # read_pos = HEIGHT-1 (start at bottom)
    
RowLoop_Gravity:
    blt $s5, $zero, NextCol_Gravity
    
    # Read from read_pos
    mul $t0, $s5, $s1
    add $t1, $t0, $s4
    sll $t2, $t1, 2
    add $t3, $s2, $t2     
    lw $t4, 0($t3)              # gem at read_pos
    
    # If empty, just move to next
    beq $t4, $s3, NextRead
    
    # Found a gem - write it to write_pos
    # Calculate write address
    mul $t5, $s6, $s1
    add $t6, $t5, $s4
    sll $t7, $t6, 2
    add $t8, $s2, $t7           
    
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
    
    addi $sp, $sp, -4
    sw $t4, 0($sp)                  # Save current Color (C0)
    
    lw $t4, 0($sp)                  # Restore $t4 (C0)
    addi $sp, $sp, 4                # Restore $sp

    # Set up start X for Check_Direction
    move $s7, $s6                 
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
    # Check Diagonal Down-Right (dx=1, dy=1). Check if X <= 3 AND Y <= 15 
    li $t0, 3
    bgt $s7, $t0, Skip_Check_DR      # If X > 3, skip
    li $t1, 15                       # Y limit is 15 (18 rows total)
    bgt $s5, $t1, Skip_Check_DR      # If Y > 15, skip
    
    # Call Check_Direction for Diagonal Down-Right
    li $a0, 1                       # dX = 1
    li $a1, 1                       # dY = 1
    move $a2, $s5                   # $a2 = Current Y
    jal Check_Direction
    or $s0, $s0, $v0
    
Skip_Check_DR:
    # Check Diagonal Down-Left (dx=-1, dy=1). Check if X >= 2 AND Y <= 15 
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
    addi $s6, $s6, 1                 # X++ if no match found
    j MatchXLoop

NextY_Match:
    addi $s5, $s5, 1                 # Y++ if no match found
    j MatchYLoop

Restart_Match_Scan:
    # Reset loop counters
    li $s5, 0                       # Y = 0
    li $s6, 0                       # X = 0
    j MatchYLoop                    # Go back to the start of the Y loop
    
MatchLoopEnd:
    move $v0, $s0                   # Return match_found_flag in $v0

    # Restore registers
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


# Function: Check_Direction
# Checks if the adjacent gem colour in the specified direction is a match
# Returns $v0 = 1 if match found
Check_Direction: 
    # Save $ra and used $s registers ($s0, $s1, $s2, $s3)
    addi $sp, $sp, -20          
    sw $ra, 16($sp)
    sw $s0, 12($sp)                
    sw $s1, 8($sp)               
    sw $s2, 4($sp)              
    sw $s3, 0($sp)                

    li $v0, 0                      # Default return value: 0 (No match cleared)

    # Setup constants/variables
    lw $t0, GRID_WIDTH             # $t0 = W (6)
    la $s0, GAME_GRID              # $s0 = &GAME_GRID
    lw $t2, EMPTY_COLOR            # $t2 = EMPTY (0)
    
    move $t3, $s7                  # $t3 = X (start X)
    move $t4, $a2                  # $t4 = Y (start Y)
    
    # gem 0: (X, Y)
    # bounds check for Gem 0
    blt $t3, $zero, DirEnd_NoMatch
    bge $t3, $t0, DirEnd_NoMatch
    blt $t4, $zero, DirEnd_NoMatch
    lw $t9, GRID_HEIGHT            
    bge $t4, $t9, DirEnd_NoMatch
    
    mul $t6, $t4, $t0              # $t6 = Y * W
    add $t6, $t6, $t3              # $t6 = Index 0
    sll $t6, $t6, 2
    add $s3, $s0, $t6              # $s3 = Address 0
    lw $t8, 0($s3)                 # $t8 = Color 0 (C0)
    move $t5, $t8                 
    
    beq $t8, $t2, DirEnd_NoMatch   # If C0 is empty, no match possible.
    
    # gem 1: (X+dX, Y+dY)
    add $t3, $t3, $a0              # X = X + dX
    add $t4, $t4, $a1              # Y = Y + dY
    
    # bounds check for Gem 1
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
    
    # gem 2: (X+2dX, Y+2dY)
    add $t3, $t3, $a0              # X = X + dX
    add $t4, $t4, $a1              # Y = Y + dY
    
    # Bounds check for Gem 2
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
    
    bne $t8, $t5, DirEnd_NoMatch   # Compare C2 ($t8) with C0 ($t5)
    
MatchFound:
    addi $sp, $sp, -12
    sw $t3, 8($sp)  # Save X
    sw $t4, 4($sp)  # Save Y
    sw $t6, 0($sp)  # Save Index
    
    # Clear the three gems
    sw $t2, 0($s3)                 # Clear Gem 0
    sw $t2, 0($s1)                 # Clear Gem 1
    sw $t2, 0($s2)                 # Clear Gem 2
    
    # Update score: 3 gems cleared
    jal Update_Score               # Call score update function
    
    lw $t6, 0($sp)
    lw $t4, 4($sp)
    lw $t3, 8($sp)
    addi $sp, $sp, 12
    
    li $v0, 1
    j CD_Return
    
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
    
# Function: Update_Score
# Updates score based on gems cleared and chain level
# Each gem = 10 points * (1 + chain_level)
Update_Score:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $t0, 0($sp)
    
    lw $t0, score           # Load current score
    lw $t1, chain_level     # Load chain level
    
    # Calculate points: 1 * 3 gems * (1 + chain_level)
    li $t2, 3               # Base points (1 per gem * 3 gems)
    addi $t3, $t1, 1        # Multiplier = 1 + chain_level
    mul $t2, $t2, $t3       # Points = base * multiplier
    
    add $t0, $t0, $t2       # Add to score
    sw $t0, score           # Save new score
    
    # Increment chain level for next match
    addi $t1, $t1, 1
    sw $t1, chain_level
    
    jal Draw_Score
    
    lw $t0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# Function: Reset_Chain
# Resets chain level to 0 (call when no more matches found)
Reset_Chain:
    sw $zero, chain_level
    jr $ra

# Function: Erase_Score_Area
# Clears the score display area before redrawing
Erase_Score_Area:
    addi $sp, $sp, -8
    sw $s0, 4($sp)
    sw $s1, 0($sp)
    
    lw $s0, ADDR_DSPL       # $s0 = display base
    li $t0, 8               # Start X (moved left, inside play area)
    li $t1, 19              # Start Y (below the play area)
    li $t2, 24              # Width (enough for 6 digits: 6*4=24 pixels)
    li $t3, 6               # Height (5 pixels for digits + 1 buffer)
    
Erase_Score_Y_Loop:
    beq $t3, $zero, Erase_Score_Done
    li $t4, 0               # X counter
    
Erase_Score_X_Loop:
    beq $t4, $t2, Erase_Score_Next_Y
    
    # Calculate display address
    add $t5, $t0, $t4       # X position
    sll $t6, $t1, 7         # Y * 128
    sll $t5, $t5, 2         # X * 4
    add $t6, $t6, $t5       # Combined offset
    add $t6, $s0, $t6       # Final address
    sw $zero, 0($t6)        # Clear pixel (set to black)
    
    addi $t4, $t4, 1
    j Erase_Score_X_Loop
    
Erase_Score_Next_Y:
    addi $t1, $t1, 1
    addi $t3, $t3, -1
    j Erase_Score_Y_Loop
    
Erase_Score_Done:
    lw $s1, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra
    
# Function: Draw_Score
# Draws the score as digits on the display
# Display position: Top-right corner (X=20, Y=1)
Draw_Score:
    addi $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)
    sw $s1, 12($sp)
    sw $s2, 8($sp)
    sw $s3, 4($sp)
    sw $s4, 0($sp)          # Add $s4 for power of 10
    
    # Clear the score area first
    jal Erase_Score_Area
    
    lw $s0, score           # $s0 = score value
    li $s1, 8               # $s1 = starting X position
    li $s2, 19              # $s2 = Y position
    li $s4, 100000          # $s4 = power of 10 (use $s register!)
    move $s3, $s0           # $s3 = remaining score
    
Draw_Score_Loop:
    beq $s4, $zero, Draw_Score_End    # Exit if power is 0
    
    # Save power before divisions
    move $t8, $s4
    
    # Calculate digit = (score / power) % 10
    div $s0, $t8
    mflo $t2
    li $t3, 10
    div $t2, $t3
    mfhi $a0                # $a0 = digit
    
    # Special handling for last digit (power=1)
    li $t1, 1
    bne $t8, $t1, Not_Last_Digit
    move $a1, $s1
    move $a2, $s2
    jal Draw_Digit
    j Draw_Score_End        
    
Not_Last_Digit:
    # Skip leading zeros
    beq $a0, $zero, Check_If_Leading_Zero
    j Draw_This_Digit
    
Check_If_Leading_Zero:
    li $t1, 8
    beq $s1, $t1, Skip_Digit
    
Draw_This_Digit:
    move $a1, $s1
    move $a2, $s2
    jal Draw_Digit
    addi $s1, $s1, 4
    
Skip_Digit:
    li $t1, 10
    div $t8, $t1
    mflo $s4
    j Draw_Score_Loop
    
Draw_Score_End:
    lw $s4, 0($sp)
    lw $s3, 4($sp)
    lw $s2, 8($sp)
    lw $s1, 12($sp)
    lw $s0, 16($sp)
    lw $ra, 20($sp)
    addi $sp, $sp, 24
    jr $ra

# Function: Draw_Digit
# Draws a single digit at specified position
# Arguments: $a0 = digit (0-9), $a1 = X, $a2 = Y
Draw_Digit:
    # reserving space in stack
    addi $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)
    sw $s1, 12($sp)
    sw $s2, 8($sp)
    sw $s3, 4($sp)
    sw $s4, 0($sp)
    
    # Get digit pattern address directly using branches
    move $s0, $a0       
    la $t0, digit_0
    beq $s0, 0, Got_Digit_Addr
    la $t0, digit_1
    beq $s0, 1, Got_Digit_Addr
    la $t0, digit_2
    beq $s0, 2, Got_Digit_Addr
    la $t0, digit_3
    beq $s0, 3, Got_Digit_Addr
    la $t0, digit_4
    beq $s0, 4, Got_Digit_Addr
    la $t0, digit_5
    beq $s0, 5, Got_Digit_Addr
    la $t0, digit_6
    beq $s0, 6, Got_Digit_Addr
    la $t0, digit_7
    beq $s0, 7, Got_Digit_Addr
    la $t0, digit_8
    beq $s0, 8, Got_Digit_Addr
    la $t0, digit_9
    
Got_Digit_Addr:
    move $s0, $t0           # $s0 = address of digit pattern
    
    lw $s1, ADDR_DSPL       # $s1 = display base
    lw $s2, score_color     # $s2 = color
    move $s3, $a2           # $s3 = current Y (0-6 for 7 rows)
    
Draw_Digit_Row_Loop:
    li $t0, 5
    add $t1, $a2, $t0
    bge $s3, $t1, Draw_Digit_End    # If row >= 7, done
    
    # Load row pattern
    sub $t1, $s3, $a2       # Row offset
    add $t2, $s0, $t1       # Pattern address
    lbu $t3, 0($t2)         # $t3 = row pattern (5 bits)
    
    # Draw 5 pixels in this row
    li $s4, 0               # $s4 = pixel column (0-4)
    
Draw_Digit_Pixel_Loop:
    beq $s4, 3, Draw_Digit_Next_Row
    
    li $t4, 0b100
    srlv $t4, $t4, $s4      # Shift right by column number
    and $t5, $t3, $t4       # Check if bit is set
    beq $t5, $zero, Draw_Digit_Skip_Pixel
    
    # Calculate display address
    add $t6, $a1, $s4       # X + column
    sll $t7, $s3, 7         # Y * 128
    sll $t6, $t6, 2         # X * 4
    add $t7, $t7, $t6       # Combined offset
    add $t7, $s1, $t7       # Final address
    sw $s2, 0($t7)          # Draw pixel
    
Draw_Digit_Skip_Pixel:
    addi $s4, $s4, 1
    j Draw_Digit_Pixel_Loop
    
Draw_Digit_Next_Row:
    addi $s3, $s3, 1
    j Draw_Digit_Row_Loop
    
Draw_Digit_End:
    lw $s4, 0($sp)
    lw $s3, 4($sp)
    lw $s2, 8($sp)
    lw $s1, 12($sp)
    lw $s0, 16($sp)
    lw $ra, 20($sp)
    addi $sp, $sp, 24
    jr $ra
    
Handle_GameOver:
    jal drawGameOverScreen

    jal resetGame       # Retry path: reset all game state and start fresh
    jal clearDisplay
    
    # Show difficulty selection screen
    jal showDifficultyScreen
    jal selectDifficulty
    jal applyDifficultySettings
    
    jal clearDisplay
    jal drawBorder       # Re-draw things and continue the main game loop
    jal drawCol          
    jal Draw_Game_Grid
    jal drawCurrCol
    b game_loop
    
# Function: drawGameOverScreen
drawGameOverScreen:
    addi $sp, $sp, -8
    sw $ra, 4($sp)       
    sw $s0, 0($sp)         
    
    lw $s0, ADDR_DSPL           # display base
    li $t1, 0                   # clear color
    li $t2, 0                   # y = 0

clear_rows:
    li $t3, 128                 # width (columns)
    beq $t2, 128, done          # if y == 128, finished
    sll $t4, $t2, 7             # row_base = y * 128 (bytes)
    li $t5, 0                   # x = 0

clear_cols:
    beq $t5, $t3, next_row
    sll $t6, $t5, 2             # col_offset = x * 4
    add $t7, $t4, $t6           # row_base + col_offset
    add $t7, $s0, $t7           # final address = display_base + offset
    sw $t1, 0($t7)              # clear pixel
    addi $t5, $t5, 1
    j clear_cols

next_row:
    addi $t2, $t2, 1
    j clear_rows
done:
    lw $t0, ADDR_DSPL                   # $t0 = ADDR_DSPL
    lw $t1, gameOver_colour             # $t1 = borderColour
    addi $t2, $t0, 0                    # $t2 = top left corner (starting point)
    
    # Letter G
    addi $t4, $t0, 780
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 8($t4)
    sw $t1, 12($t4)
    sw $t1, 16($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    sw $t1, 516($t4)
    sw $t1, 520($t4)
    sw $t1, 524($t4)
    sw $t1, 528($t4)
    sw $t1, 268($t4)
    sw $t1, 272($t4)
    sw $t1, 400($t4)
    
    # Letter A
    addi $t4, $t0, 808
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 8($t4)
    sw $t1, 12($t4)
    sw $t1, 16($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    sw $t1, 144($t4)
    sw $t1, 272($t4)
    sw $t1, 400($t4)
    sw $t1, 528($t4)
    sw $t1, 388($t4)
    sw $t1, 392($t4)
    sw $t1, 396($t4)
    sw $t1, 400($t4)

    # Letter M
    addi $t4, $t0, 836
    sw $t1, 0($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    sw $t1, 132($t4)
    sw $t1, 264($t4)
    sw $t1, 140($t4)
    sw $t1, 16($t4)
    sw $t1, 144($t4)
    sw $t1, 272($t4)
    sw $t1, 400($t4)
    sw $t1, 528($t4)
    
    # Letter E_1
    addi $t4, $t0, 864
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 8($t4)
    sw $t1, 12($t4)
    sw $t1, 16($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    sw $t1, 260($t4)
    sw $t1, 264($t4)
    sw $t1, 516($t4)
    sw $t1, 520($t4)
    sw $t1, 524($t4)
    sw $t1, 528($t4)

    # Letter O
    addi $t4, $t0, 1676
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 8($t4)
    sw $t1, 12($t4)
    sw $t1, 16($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    sw $t1, 516($t4)
    sw $t1, 520($t4)
    sw $t1, 524($t4)
    sw $t1, 528($t4)
    sw $t1, 144($t4)
    sw $t1, 272($t4)
    sw $t1, 400($t4)
    sw $t1, 528($t4)
    
    # Letter V
    addi $t4, $t0, 1704
    sw $t1, 0($t4)
    sw $t1, 16($t4)
    sw $t1, 128($t4)
    sw $t1, 144($t4)
    sw $t1, 260($t4)
    sw $t1, 268($t4)
    sw $t1, 388($t4)
    sw $t1, 396($t4)
    sw $t1, 520($t4)
    
    # Letter E_2
    addi $t4, $t0, 1732
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 8($t4)
    sw $t1, 12($t4)
    sw $t1, 16($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    sw $t1, 260($t4)
    sw $t1, 264($t4)
    sw $t1, 516($t4)
    sw $t1, 520($t4)
    sw $t1, 524($t4)
    sw $t1, 528($t4)

    # Letter R
    addi $t4, $t0, 1760
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 8($t4)
    sw $t1, 12($t4)
    sw $t1, 16($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    sw $t1, 260($t4)
    sw $t1, 264($t4)
    sw $t1, 268($t4)
    sw $t1, 272($t4)
    sw $t1, 144($t4)
    sw $t1, 392($t4)
    sw $t1, 524($t4)
    sw $t1, 528($t4)
    
# Function: GameOverOptions
gameOverOptions:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $t0, 0($sp)    

gameOverOptionsLoop:
    li $v0, 32
    li $a0, 100
    syscall

    lw $t0, ADDR_KBRD
    lw $t1, 0($t0)
    beq $t1, 1, gameOverOptionsKeyInput
    j gameOverOptionsLoop

gameOverOptionsKeyInput:
    lw $t2, 4($t0)                
    beq $t2, 0x72, gameOverRetry
    beq $t2, 0x71, gameOverQuit
    j gameOverOptionsLoop

gameOverRetry:
    li $v0, 1
    j gameOverOptionsLoopEnd

gameOverQuit:
    li $v0, 10
    syscall

gameOverOptionsLoopEnd:
    lw $t0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra
    
# Function: resetGame
resetGame:
    addi $sp, $sp, -12
    sw $ra, 8($sp)
    sw $t0, 4($sp)
    sw $t1, 0($sp)

    la $t0, GAME_GRID
    li $t1, 108
    
resetGameClearLoop:
    beq $t1, $zero, resetGameClearEnd
    sw $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    j resetGameClearLoop
    
resetGameClearEnd:
    la $t0, score
    sw $zero, 0($t0)
    la $t0, chain_level
    sw $zero, 0($t0)

    li $t1, 2
    la $t0, currColX
    sw $t1, 0($t0)
    li $t1, 1
    la $t0, currColY
    sw $t1, 0($t0)

    la $t0, currCol0
    sw $zero, 0($t0)
    la $t0, currCol1
    sw $zero, 0($t0)
    la $t0, currCol2
    sw $zero, 0($t0)

    la $t0, gravity_timer
    sw $zero, 0($t0)
    la $t0, gravity_elapsed
    sw $zero, 0($t0)
    
    # Reset difficulty flag to show menu again
    la $t0, difficulty_selected
    sw $zero, 0($t0)
    
    lw $t1, 0($sp)
    lw $t0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra
    
# Function: genNextCol
genNextCol:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
clearDisplay:
    addi $sp, $sp, -8
    sw $ra, 4($sp)

    lw $t0, ADDR_DSPL               # $t0 = ADDR_DSPL
    li $t1, 0                       # $t1 = 0 (no colour)
    li $t2, 0                       # y = 0

clearDisplayRows:
    li $t3, 128                     # $t3 = 128
    beq $t2, $t3, clearDisplayEnd   # if y == 128 clearDisplayEnd
    sll $t4, $t2, 7                 # row = y * 128
    li $t5, 0                       # x = 0

clearDisplayCols:
    beq $t5, $t3, clearDisplayNextRow
    sll $t6, $t5, 2                 # col offset = x * 4
    add $t7, $t4, $t6               # row + col offset
    add $t7, $t0, $t7               # address = ADDR_DSPL + offset
    sw $t1, 0($t7)                  # draw clear pixel
    addi $t5, $t5, 1
    j clearDisplayCols

clearDisplayNextRow:
    addi $t2, $t2, 1
    j clearDisplayRows

clearDisplayEnd:
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# Function: showDifficultyScreen
# Displays the difficulty selection menu
showDifficultyScreen:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)
    
    lw $s0, ADDR_DSPL
    lw $t1, borderColour
    
    # Draw "EASY" at Y=6
    addi $t4, $s0, 780          
    # E
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 8($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 260($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    sw $t1, 516($t4)
    sw $t1, 520($t4)
    
    # A
    addi $t4, $s0, 796
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 8($t4)
    sw $t1, 128($t4)
    sw $t1, 136($t4)
    sw $t1, 256($t4)
    sw $t1, 260($t4)
    sw $t1, 264($t4)
    sw $t1, 384($t4)
    sw $t1, 392($t4)
    sw $t1, 512($t4)
    sw $t1, 520($t4)
    
    # S
    addi $t4, $s0, 812
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 8($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 260($t4)
    sw $t1, 264($t4)
    sw $t1, 392($t4)
    sw $t1, 512($t4)
    sw $t1, 516($t4)
    sw $t1, 520($t4)
    
    # Y
    addi $t4, $s0, 828
    sw $t1, 0($t4)
    sw $t1, 8($t4)
    sw $t1, 128($t4)
    sw $t1, 136($t4)
    sw $t1, 260($t4)
    sw $t1, 388($t4)
    sw $t1, 516($t4)
    
    # (
    addi $t4, $s0, 860
    sw $t1, 0($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    
    # 1
    addi $t4, $s0, 868
    sw $t1, 4($t4)
    sw $t1, 128($t4)
    sw $t1, 132($t4)
    sw $t1, 260($t4)
    sw $t1, 388($t4)
    sw $t1, 512($t4)
    sw $t1, 516($t4)
    sw $t1, 520($t4)
    
    # )
    addi $t4, $s0, 884
    sw $t1, 0($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    
    # Draw "MEDIUM" at Y=11
    addi $t4, $s0, 1548
    # M
    sw $t1, 0($t4)     
    sw $t1, 16($t4)    
    sw $t1, 128($t4)   
    sw $t1, 132($t4)   
    sw $t1, 140($t4)   
    sw $t1, 144($t4)   
    sw $t1, 256($t4)  
    sw $t1, 264($t4)   
    sw $t1, 272($t4)   
    sw $t1, 384($t4)    
    sw $t1, 400($t4)    
    sw $t1, 512($t4)    
    sw $t1, 528($t4)   
    
    # E
    addi $t4, $s0, 1572
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 8($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 260($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    sw $t1, 516($t4)
    sw $t1, 520($t4)
    
    # D
    addi $t4, $s0, 1588
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 128($t4)
    sw $t1, 136($t4)
    sw $t1, 256($t4)
    sw $t1, 264($t4)
    sw $t1, 384($t4)
    sw $t1, 392($t4)
    sw $t1, 512($t4)
    sw $t1, 516($t4)
    
    # (
    addi $t4, $s0, 1628
    sw $t1, 0($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    
    # 2
    addi $t4, $s0, 1636
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 8($t4)
    sw $t1, 136($t4)
    sw $t1, 256($t4)
    sw $t1, 260($t4)
    sw $t1, 264($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    sw $t1, 516($t4)
    sw $t1, 520($t4)
    
    # )
    addi $t4, $s0, 1652
    sw $t1, 0($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    
    # Draw "HARD" at Y=16
    addi $t4, $s0, 2444
    # H
    sw $t1, 0($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 260($t4)
    sw $t1, 264($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    sw $t1, 8($t4)
    sw $t1, 136($t4)
    sw $t1, 264($t4)
    sw $t1, 392($t4)
    sw $t1, 520($t4)
    
    # A
    addi $t4, $s0, 2460
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 8($t4)
    sw $t1, 128($t4)
    sw $t1, 136($t4)
    sw $t1, 256($t4)
    sw $t1, 260($t4)
    sw $t1, 264($t4)
    sw $t1, 384($t4)
    sw $t1, 392($t4)
    sw $t1, 512($t4)
    sw $t1, 520($t4)
    
    # R
    addi $t4, $s0, 2476
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 8($t4)
    sw $t1, 128($t4)
    sw $t1, 136($t4)
    sw $t1, 256($t4)
    sw $t1, 260($t4)
    # sw $t1, 264($t4)
    sw $t1, 384($t4)
    sw $t1, 392($t4)
    sw $t1, 512($t4)
    sw $t1, 520($t4)
    
    # D
    addi $t4, $s0, 2492
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 128($t4)
    sw $t1, 136($t4)
    sw $t1, 256($t4)
    sw $t1, 264($t4)
    sw $t1, 384($t4)
    sw $t1, 392($t4)
    sw $t1, 512($t4)
    sw $t1, 516($t4)
    
    # (
    addi $t4, $s0, 2524
    sw $t1, 0($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    
    # 3
    addi $t4, $s0, 2532
    sw $t1, 0($t4)
    sw $t1, 4($t4)
    sw $t1, 8($t4)
    sw $t1, 136($t4)
    sw $t1, 256($t4)
    sw $t1, 260($t4)
    sw $t1, 264($t4)
    sw $t1, 392($t4)
    sw $t1, 512($t4)
    sw $t1, 516($t4)
    sw $t1, 520($t4)
    
    # )
    addi $t4, $s0, 2548
    sw $t1, 0($t4)
    sw $t1, 128($t4)
    sw $t1, 256($t4)
    sw $t1, 384($t4)
    sw $t1, 512($t4)
    
    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# Function: selectDifficulty
# Waits for player to press 1 (Easy), 2 (Medium), or 3 (Hard)
selectDifficulty:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    lw $t9, ADDR_KBRD
    
selectDifficultyLoop:
    # Sleep briefly
    li $v0, 32
    li $a0, 50
    syscall
    
    # Check for key press
    lw $t0, 0($t9)
    beq $t0, $zero, selectDifficultyLoop
    
    # Get key code
    lw $t1, 4($t9)
    
    # Check for 1, 2, or 3
    li $t2, 0x31                   
    beq $t1, $t2, setEasy
    li $t2, 0x32                   
    beq $t1, $t2, setMedium
    li $t2, 0x33                   
    beq $t1, $t2, setHard
    
    j selectDifficultyLoop

setEasy:
    li $t0, 0
    la $t1, difficulty_level
    sw $t0, 0($t1)
    j difficultySelected
    
setMedium:
    li $t0, 1
    la $t1, difficulty_level
    sw $t0, 0($t1)
    j difficultySelected
    
setHard:
    li $t0, 2
    la $t1, difficulty_level
    sw $t0, 0($t1)
    j difficultySelected

difficultySelected:
    li $t0, 1
    la $t1, difficulty_selected
    sw $t0, 0($t1)
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# Function: applyDifficultySettings
# Sets game parameters based on selected difficulty
applyDifficultySettings:
    addi $sp, $sp, -4
    sw $t0, 0($sp)
    
    la $t0, difficulty_level
    lw $t0, 0($t0)
    
    # Easy = 0
    beq $t0, $zero, applyEasy
    # Medium = 1
    li $t1, 1
    beq $t0, $t1, applyMedium
    # Hard = 2
    j applyHard

applyEasy:
    la $t2, easy_interval
    lw $t1, 0($t2)
    la $t2, gravity_interval
    sw $t1, 0($t2)
    
    la $t2, easy_increase
    lw $t1, 0($t2)
    la $t2, gravity_increase
    sw $t1, 0($t2)
    
    la $t2, easy_decrement
    lw $t1, 0($t2)
    la $t2, gravity_decrement
    sw $t1, 0($t2)
    
    la $t2, easy_min
    lw $t1, 0($t2)
    la $t2, gravity_min
    sw $t1, 0($t2)
    j applyDone

applyMedium:
    la $t2, medium_interval
    lw $t1, 0($t2)
    la $t2, gravity_interval
    sw $t1, 0($t2)
    
    la $t2, medium_increase
    lw $t1, 0($t2)
    la $t2, gravity_increase
    sw $t1, 0($t2)
    
    la $t2, medium_decrement
    lw $t1, 0($t2)
    la $t2, gravity_decrement
    sw $t1, 0($t2)
    
    la $t2, medium_min
    lw $t1, 0($t2)
    la $t2, gravity_min
    sw $t1, 0($t2)
    j applyDone

applyHard:
    la $t2, hard_interval
    lw $t1, 0($t2)
    la $t2, gravity_interval
    sw $t1, 0($t2)
    
    la $t2, hard_increase
    lw $t1, 0($t2)
    la $t2, gravity_increase
    sw $t1, 0($t2)
    
    la $t2, hard_decrement
    lw $t1, 0($t2)
    la $t2, gravity_decrement
    sw $t1, 0($t2)
    
    la $t2, hard_min
    lw $t1, 0($t2)
    la $t2, gravity_min
    sw $t1, 0($t2)

applyDone:
    lw $t0, 0($sp)
    addi $sp, $sp, 4
    jr $ra