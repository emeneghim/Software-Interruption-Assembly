.code16                   
.text                  
.globl _start;

_start:
    cli                     # Inibir Interrupções
    
    # Configurar Tabela de Interrupções para atender a interrupção de teclado
    movw $0x0, %ax          
    movw %ax, %ds          
    movw $0x204,%bx         
    movw $0x7d00, (%bx)

_setPIC:
    # Configuração do PIC

    # CONFIGURANDO PRIMEIRO PIC (master)
    movb $0x11, %al
    outb  %al, $0x20  # Mandando ICW1 no primeiro PIC -> 0001 0001: ICW4 é necessário
    movb $0x80, %al
    outb  %al, $0x21  # Mandando ICW2 no primeiro PIC -> 1000 0000: define a interrupcao que sera chamada (80)
    movb $0x04, %al
    outb  %al, $0x21  # Mandando ICW3 no primeiro PIC -> 0000 0100: tem um slave
    movb $0x01, %al
    outb  %al, $0x21  # Mandando ICW4 no primeiro PIC -> 0000 0001: modo 8086/8088
    movb $0xfd, %al 
    outb %al, $0x21   # Inibindo todas as interrupções, exceto teclado (OCW1)


    # CONFIGURANDO SEGUNDO PIC (slave)
    movb $0x11, %al
    outb  %al, $0xa0  # Mandando ICW1 no segundo PIC -> 0001 0001: ICW4 é necessário
    movb $0x80, %al
    outb  %al, $0xa1  # Mandando ICW2 no segundo PIC -> 1000 0000: define a interrupcao que sera chamada (80)
    movb $0x02, %al
    outb  %al, $0xa1  # Mandando ICW3 no segundo PIC -> 0000 0010: indica 00110011 ?? que que isso significa?
    movb $0x01, %al
    outb  %al, $0xa1  # Mandando ICW4 no segundo PIC -> 0000 0001: modo 8086/8088
    movb $0xff, %al 
    outb %al, $0xa1   # Inibindo todas as interrupções, exceto teclado (OCW1)

    movb $0xfd, %al     # Mandando OCW1 no Primeiro PIC
    outb %al, $0x21
    movb $0xff, %al     # Mandando OCW1 no Segundo PIC
    outb %al, $0xa1


.desabilitaTeclado: 
    movb $0xad, %al
    outb %al, $0x64     # Desabilita porta um
    movb $0xa7, %al
    outb %al, $0x64     # Desabilita porta dois

.habilitaInterrupcao:
    movb $0x20, %al     # Requisitando leitura do status PS/2 
    outb %al, $0x64

    movb $0x60, %al     # Lendo o status
    in $0x60, %al 
    orb $0x01, %al     # Desabilitando bits 0,1 e 6 e deixando 0 onde deve ser 0
    movb %al, %dl

    movb $0x60, %al     # Escrevendo configuração
    outb %al, $0x64
    movb %dl, %al
    outb %al, $0x60

    movb $0xAE, %al     # Habilitar porta 1 do PS/2
    outb %al, $0x64 

    movb $0xF4, %al     # Habilitar porta 1 do PS/2
    outb %al, $0x64         


_setProcessTable:
    # Configuração Inicial da Tabela de Processos + Ajuste da Pilha

    movw $0x1000, %dx
    movw %dx, %ds
    movw $0x8000, %dx
    movw %dx, %ss

    mov $0xffff, %sp
    mov $0xffff, %bp

    movw $0x200, (0x0)
    movw $0x0, (0x2)
    movw $0x7cd0, (0x4)
    movw $0xffff, (0xe)
    movw $0xffff, (0x10)
    movw $0x1000, (0x16)
    movw $0x8000, (0x18)

    movw $0x200, (0x1c)
    movw $0x0, (0x1e)
    movw $0x7ce0, (0x20)
    movw $0xffff, (0x2a)
    movw $0xffff, (0x2c)
    movw $0x1000, (0x32)
    movw $0x8000, (0x34)
    movw $0x0, (0x38)
    
    sti                         # Permitir Interrupções

proc0:
    # 1º 'Processo'
    . = _start + 208
    movb $'0', %al      
    movb $0x0e, %ah     
    int  $0x10
    jmp proc0

proc1:
    # 2º 'Processo'
    . = _start + 224
    movb $'1', %al      
    movb $0x0e, %ah     
    int  $0x10
    jmp proc1

intKBD:
    # Rotina para tratar a Interrupção do Teclado
    . = _start + 256 
    cli
    
    # Salvar registradores na pilha
    pusha
    push %ds
    push %ss
    push %es

    # Verifica se uma tecla foi pressionada, ou solta
    inb $0x60, %al
    test $0x80, %al
    
    jnz _key_released       # Se foi solta -> Troca de processo
    jmp _finish             # Se foi pressionada -> Não faz nada (não troca de processo)

_key_released:
    # Verifica qual processo estava rodando antes da interrupção e define onde salvar 
    # os dados do processo na tabela de processos
    cmpw $0x0, (0x38)
    jne _defineSaveP2

_defineSaveP1:
    # Estava rodando o 1º Processo
    movw $0x1a, %bx
    jmp _saveProc

_defineSaveP2:
     # Estava rodando o 2º Processo
    movw $0x36, %bx

_saveProc:
    # Salva os dados do processo (que estão na pilha) na memória (tabela de processos)
    movw $0xe, %cx

_loopSaveProc:
    # Loop para retirar da pilha e armazenar na memória
    pop (%bx)
    sub $0x2, %bx
    dec %cx
    cmpw $0x0, %cx
    jne _loopSaveProc

_loadProc:
    # Verifica qual processo deve ser carregado em sequência (o oposto ao processo que foi salvo)
    cmpw $0x0, (0x38)
    je _defineLoadP2

_defineLoadP1:
    # 1º Processo deve ser carregado
    movw $0x0, %bx
    movw $0x0, (0x38)
    jmp _continueLoadProc

_defineLoadP2:
    # 2º Processo deve ser carregado
    movw $0x1c, %bx
    movw $0x1, (0x38)

_continueLoadProc:
    movw $0xe, %cx

_loopLoadProc:
    # Empilhando dados do processo (que estão em memória)
    push (%bx)
    add $0x2, %bx
    dec %cx
    cmpw $0x0, %cx
    jne _loopLoadProc

_finish:
    movb $0x20, %al
    outb %al, $0x20 

    # Desempilhar os dados do processo - atribuindo cada valor para seu respectivo registrador
    pop %es
    pop %ss
    pop %ds
    popa
    
    sti
    iret  

_end:                   
	. = _start + 510      
    .byte 0x55            
    .byte 0xaa             
