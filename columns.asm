################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Kristen Wong, 1011088225
# Student 2: Name, Student Number (if applicable)
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

##############################################################################
# Mutable Data
##############################################################################

##############################################################################
# Code
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
currColX:      .word 4                  # Column X position 
currColY:      .word 1                  # Column Y position 
	
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
    j game_loop
    # 1b. Check which key has been pressed
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleep

    # 5. Go back to Step 1
CheckKeyboardInput:
	li 		$v0, 32
	li 		$a0, 1
	syscall
    lw $t0, ADDR_KBRD                  # $t0 = ADDR_KBRD
    lw $t1, 0($t0)                     # Check if key was pressed and stored in $t1
    beq $t1, 1, CheckKeyInput          # Check which key was pressed
    b game_loop
    
CheckKeyInput:
    lw $t2, 4($t0)
    beq $t2, 0x77, respondToW          # Check if the key W was pressed
    beq $t2, 0x61, respondToA          # Check if the key A was pressed
    beq $t2, 0x73, respondToS          # Check if the key S was pressed
    beq $t2, 0x64, respondToD          # Check if the key D was pressed
    beq $t2, 0x71, respondToQ          # Check if the key Q was pressed
    j game_loop

respondToW:
    jal shuffleCurrCol
    j game_loop

respondToA:
    jal moveCurrLeft
    j game_loop
    
respondToS:
    jal moveCurrDown
    j game_loop
    
respondToD:
    jal moveCurrRight
    j game_loop
    
respondToQ:
    li $v0, 10                         # Quit game
	syscall

drawCurrCol:
    lw $t0, ADDR_DSPL                  # $t0 = ADDR_DSPL 
    lw $t1, currColX                   # $t1 = currColX 
    lw $t2, currColY                   # $t2 = currColY  
    
    lw $t3, currCol0                   # $t3 = currCol0 
    sll $t4, $t2, 7                    # $t4 = $t2 * 128 - Logical left shift by 7 to move one row down
    sll $t5, $t1, 2                    # $t5 = $t1 * 4 - Logical left shift by 2 to move one column right 
    add $t6, $t4, $t5                  # $t6 = $t4 + $t5 - Total offset 
    add $t7, $t0, $t6                  # Address to draw
    sw $t3, 0($t7)                     # Draw top gem 
    
    lw $t3, currCol1                   # $t3 = currCol1 
    addi $t8, $t2, 1                   # Same as above but currColY + 1 
    sll $t4, $t8, 7
    add $t6, $t4, $t5
    add $t7, $t0, $t6
    sw $t3, 0($t7)                     # Draw middle gem

    lw $t3, currCol2
    addi $t8, $t2, 2                   # currColY + 2
    sll $t4, $t8, 7
    add $t6, $t4, $t5
    add $t7, $t0, $t6
    sw $t3, 0($t7)                     # Draw bottom gem

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
    
    lw $t9, currColX
    jal eraseCurrCol
    addi $t9, $t9, -1
    sw $t9, currColX
    jal drawCurrCol
    
    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

moveCurrDown:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)
    
    lw $t9, currColY
    jal eraseCurrCol
    addi $t9, $t9, 1
    sw $t9, currColY
    jal drawCurrCol
    
    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

moveCurrRight:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)
    
    lw $t9, currColX
    jal eraseCurrCol
    addi $t9, $t9, 1
    sw $t9, currColX
    jal drawCurrCol
    
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
    li $v0, 42                         # System call to produce a random int 
    li $a0, 0                          # min = 0 
    li $a1, 6                          # max = 5 
    syscall
    move $t0, $a0                      # Store random number in $t0 
    
    la $t1, colours                    # $t1 = array of colours 
    mul $t0, $t0, 4                    # Offset of 4 
    add $t1, $t1, $t0                  # Choose colour based on random number 
    
    lw $v0, 0($t1)                     # Store colour in $v0 
    
    jr $ra
    
