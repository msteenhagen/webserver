.intel_syntax noprefix
.globl _start
.section .text

_start:

    # First we create a socket. The socket() syscall takes 3 arguments: AF_INET=2, SOCK_STREAM=1, IP_PROTO=0
    mov rax, 41     # socket call
    mov rdi, 2      # AF_INET
    mov rsi, 1      # SOCK_STREAM
    mov rdx, 0      # IP_PROTO  TO DO: What do these values represent?
    syscall
    
    mov r10, rax    # Store socket pointer
    
    # Binding socket. This takes three arguments, the socket pointer; a socket address structure, and an int for the size of the second argument
    mov rax, 49                 # bind call
    mov rdi, r10                # Load socket pointer    
    lea rsi, [rip+sockaddr]     # Load socket address
    mov rdx, 16                 # Load socket address size
    syscall

    # Listening on socket
    mov rax, 50
    mov rdi, r10 
    mov rsi, 0
    syscall

ACCEPT:  

    # accept
    mov rax, 43                     # set the syscall for accept
    mov rdi, r10                    # socket fd
    xor rsi, rsi                    # struct sockaddr __user * upeer_sockaddr         
    xor rdx, rdx                    # int __user * upeer_addrlen
    syscall
    
    mov r8, rax # this puts the fd for the CONNECTION SOCKET in r8
    
    # Here we fork the connection. Fork doesn't take any arguments. It will return a process ID
    mov rax, 57
    syscall
    cmp rax, 0
    jne PARENT

CHILD:    

    # Close the listening socket for this process, keeping only the connection socket
    mov rax, 3
    mov rdi, r10
    syscall   

    # read
    
    mov rax, 0          # load read syscall
    mov rdi, r8         # unsigned int fd
    mov rsi, rsp        # char __user * buf
    mov rdx, 512        # size_t count
    syscall 
    mov r13, rax

    # find the path
    mov r12, rsp
    push rsp
    loop:
        mov al, [r12]
        cmp al, ' ' 
        je done
        add r12, 1
        jmp loop
    done:  # Now we have the first character. We then nibble along the string until we reach the next space.
        add r12, 1 # this is the first character
        mov rbx, r12 
        xor rcx, rcx #counter
    loop2: 
        mov al, [rbx]
        cmp al, ' '
        je done2
        add rbx, 1
        add rcx, 1
        jmp loop2
    done2: # now we have the address of the first character in r12, and the length of the string in rcx, and we can open
    

    #but is it POST or GET? 
    pop rcx # gets us the address of the request again
    mov al, [rcx]
    cmp al, 'G'
    je GET

POST: 

# Open
# Desired: open("<open_path>", O_WRONLY|O_CREAT, 0777) = 3

        #Open file at path  (This is a new file, possibly?)
        mov byte ptr[rbx], 0  # path is on the stack, the NULL at the end will help select it
        mov rdi, r12
        mov rsi, 0101
        mov rdx, 0777
        mov rax, 2
        syscall

# Find data to write

        xor rbx, rbx
        add r12, r13
            find_start_data:
                mov al, [r12]
                cmp al, 0x0A #check if we see a new line 
                je found_start
                sub r12, 1
                add rbx, 1
                jmp find_start_data
            found_start:
                add r12, 1
                sub rbx, 6

# write to file

    mov rdi, r10
    mov rsi, r12
    mov rdx, rbx
    mov rax, 1
    syscall

# Close socket
    mov rdi, r10
    mov rax, 3
    syscall

# write http response. This violates DRY, and what I should do is make an extra jump for this: HTTP-RESPONSE:, and then jmp back to process relative to child/parent id 

    # here we write a simple http response syscall, rdi takes the socketfd, rsi takes a stack pointer, and rdx the length of the string to read from stack 
    mov rax, 1
    mov rdi, r8
    # Here we're building up the response message onto the stack, in three qwords (big endian)
    mov r12, 0
    mov r12, 0x00000000000A0D0A
    push r12
    mov r12, 0
    mov r12, 0x0D4B4F2030303220 
    push r12
    mov r12, 0
    mov r12, 0x302E312F50545448
    push r12
    mov rsi, rsp
    mov rdx, 19
    syscall
    pop r12
    pop r12
    pop r12

# exit with 0

    # Kill the child process, Exit programme with 0 
    mov rdi, 0 # It's asking for exit 0
    mov rax, 60 # quit syscall 
    syscall
   

# Resume existing programme

GET:
        
        #Open file from path 
        mov byte ptr[rbx], 0  # path is on the stack, the NULL at the end will help select it
        mov rdi, r12
        mov rsi, 0
        mov rdx, 0
        mov rax, 2
        syscall

           # then we read the file
        mov rdi, rax
        mov rsi, rsp 
        mov rdx, 256
        mov rax, 0
        syscall
        xor rbx,rbx
        mov rbx, rax

       # Close from the path
    mov rdi, r10
    mov rax, 3
    syscall


    # here we write a simple http response syscall, rdi takes the socketfd, rsi takes a stack pointer, and rdx the length of the string to read from stack 
    mov rax, 1
    mov rdi, r8
    # Here we're building up the response message onto the stack, in three qwords (big endian)
    mov r12, 0
    mov r12, 0x00000000000A0D0A
    push r12
    mov r12, 0
    mov r12, 0x0D4B4F2030303220 
    push r12
    mov r12, 0
    mov r12, 0x302E312F50545448
    push r12
    mov rsi, rsp
    mov rdx, 19
    syscall
    pop r12
    pop r12
    pop r12

    # then we write the file to the connection socket

    mov rdi, r8
    mov rsi, rsp
    mov rdx, rbx
    mov rax, 1
    syscall

    # Kill the child process, Exit programme with 0 
    mov rdi, 0 # It's asking for exit 0
    mov rax, 60 # quit syscall 
    syscall
    

PARENT:

    # Close the connection socket, the connection should only be child's
    mov rax, 3
    mov rdi, r8
    syscall   
    jmp ACCEPT

    # Exit programme with 0 (We'll never get here though)
    mov rdi, 0 # It's asking for exit 0
    mov rax, 60 # quit syscall 
    syscall
    
.section .data

sockaddr: # Here we prepare the struct bit for the second argument for bind()
    .short 2            # AF_INET sa_family
    .short 0x5000       # port 80 (0x50, but note big endian!)
    .long 0x00000000    # address 0.0.0.0
    .quad 0             # padding to fill to 16 bytes

