; JOAO VICTOR DA SILVA CIRILO - 20200019609
; CARLOS ALEXANDRE SILVA DOS SANTOS - 20210025904

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\masm32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\masm32.lib

.data
    ;TEXTOS DO MENU
    menuEntrada   db "Nome do arquivo de entrada: ", 0H
    menuX         db "Pos. X inicial da censura: ", 0H
    menuY         db "Pos. Y inicial da censura: ", 0H
    menuAlt       db "Altura  da censura (px): ", 0H
    menuLarg      db "Largura da censura (px): ", 0H
    menuSaida     db "Nome do arquivo de saida: ", 0H
     
    ;DADOS DA CENSURA
    nomeEntrada     db 50 dup(0)
    nomeSaida       db 50 dup(0)
    x               dd 0
    y               dd 0
    altura          dd 0
    largura         dd 0
    larguraMaxima   dd 0

    ;VARIAVEIS DE MANIPULACAO DO CONSOLE
    consBuffer     db 50 dup(0)
    consInHandler  dd 0
    consOutHandler dd 0
    consBufferSize dd 0
    consCount      dd 0

    ;VARIAVEIS P/ MANIPULACAO DOS ARQUIVOS 
    arqLerHandler   dd 0
    arqEscHandler   dd 0
    arqLerCount     dd 0
    arqEscCount     dd 0
    arqBuffer       db 6480 dup(0)
    yAtual          dd 0

.code

censurar_linha:
    push ebp
    mov ebp, esp

    xor ecx, ecx
    mov esi, DWORD PTR [ebp+16]
censurar_linha_loop:

    ; VERIFICA SE ECX < X DA CENSURA

    xor eax, eax
    add eax, DWORD PTR[ebp+12]
    cmp ecx, eax
    jl nao_censurar

    ; VERIFICA SE ECX >= LARGURA DA CENSURA X+LARGURA-1

    add eax, DWORD PTR[ebp+8]
    cmp ecx, eax
    jge fim_censura

    ; EFETUAR CENSURA NO BUFFER

    xor edx, edx
    add edx, ecx
    imul edx, edx, 3
    mov BYTE PTR [esi+edx], 0
    mov BYTE PTR [esi+edx+1], 0
    mov BYTE PTR [esi+edx+2], 0
nao_censurar:
    inc ecx
    jmp censurar_linha_loop
fim_censura:
    mov esp, ebp
    pop ebp
    ret 12

; CODIGO DO PROFESSOR PARA REMOCAO DO CARRIAGE RETURN (MODIFICADO COMO UM PROCEDIMENTO)

remover_cr:
    push ebp
    mov ebp, esp
    mov esi, DWORD PTR [ebp+8]
cr_loop:
    mov al, [esi]
    inc esi
    cmp al, 13
    jne cr_loop
    dec esi
    xor al, al
    mov [esi], al
    mov esp, ebp
    pop ebp
    ret 4

start:
    invoke GetStdHandle, STD_OUTPUT_HANDLE
    mov consOutHandler, eax
    invoke GetStdHandle, STD_INPUT_HANDLE
    mov consInHandler, eax

menu_console:
    invoke WriteConsole, consOutHandler, addr menuEntrada, sizeof menuEntrada, addr consCount, NULL
    invoke ReadConsole, consInHandler, addr nomeEntrada, sizeof nomeEntrada, addr consCount, NULL
    push offset nomeEntrada
    call remover_cr

    invoke WriteConsole, consOutHandler, addr menuX, sizeof menuX, addr consCount, NULL
    invoke ReadConsole, consInHandler, addr consBuffer, sizeof consBuffer, addr consCount, NULL
    push offset consBuffer
    call remover_cr
    invoke atodw, addr consBuffer
    mov x, eax

    invoke WriteConsole, consOutHandler, addr menuY, sizeof menuY, addr consCount, NULL
    invoke ReadConsole, consInHandler, addr consBuffer, sizeof consBuffer, addr consCount, NULL
    push offset consBuffer
    call remover_cr
    invoke atodw, addr consBuffer
    mov y, eax

    invoke WriteConsole, consOutHandler, addr menuLarg, sizeof menuLarg, addr consCount, NULL
    invoke ReadConsole, consInHandler, addr consBuffer, sizeof consBuffer, addr consCount, NULL
    push offset consBuffer
    call remover_cr
    invoke atodw, addr consBuffer
    mov largura, eax

    invoke WriteConsole, consOutHandler, addr menuAlt, sizeof menuAlt, addr consCount, NULL
    invoke ReadConsole, consInHandler, addr consBuffer, sizeof consBuffer, addr consCount, NULL
    push offset consBuffer
    call remover_cr
    invoke atodw, addr consBuffer
    mov altura, eax

    invoke WriteConsole, consOutHandler, addr menuSaida, sizeof menuSaida, addr consCount, NULL
    invoke ReadConsole, consInHandler, addr nomeSaida, sizeof nomeSaida, addr consCount, NULL
    push offset nomeSaida
    call remover_cr

iniciar_arquivos:
    invoke CreateFile, addr nomeEntrada, GENERIC_READ, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    mov arqLerHandler, eax
    invoke CreateFile, addr nomeSaida, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    mov arqEscHandler, eax

ler_cabecalho:
    invoke ReadFile, arqLerHandler, addr arqBuffer, 18, addr arqLerCount, NULL
    invoke WriteFile, arqEscHandler, addr arqBuffer, 18, addr arqEscCount, NULL

    ; LER LARGURA DA IMAGEM E MULTIPLICA POR 3

    invoke ReadFile, arqLerHandler, addr arqBuffer, 4, addr arqLerCount, NULL
    invoke WriteFile, arqEscHandler, addr arqBuffer, 4, addr arqEscCount, NULL
    mov eax, DWORD PTR [arqBuffer]
    mov edx, 3
    mul edx
    mov larguraMaxima, eax

    invoke ReadFile, arqLerHandler, addr arqBuffer, 32, addr arqLerCount, NULL
    invoke WriteFile, arqEscHandler, addr arqBuffer, 32, addr arqEscCount, NULL

loop_leitura:
    invoke ReadFile, arqLerHandler, addr arqBuffer, larguraMaxima, addr arqLerCount, NULL
    cmp arqLerCount, 0
    je fechar_arquivos

    ; VERIFICA SE Y ATUAL < Y

    mov eax, y
    cmp eax, yAtual
    ja escrever_linha

    ; VERIFICA SE Y ATUAL >= Y+ALTURA-1

    add eax, altura
    cmp eax, yAtual
    jle escrever_linha

    push offset arqBuffer
    push x
    push largura
    call censurar_linha

escrever_linha:
    invoke WriteFile, arqEscHandler, addr arqBuffer, larguraMaxima, addr arqEscCount, NULL
    mov ecx, yAtual
    inc ecx
    mov yAtual, ecx
    jmp loop_leitura
    
fechar_arquivos:
    invoke CloseHandle, arqLerHandler
    invoke CloseHandle, arqEscHandler
    invoke GetLastError

fim_programa:
	invoke ExitProcess, 0
end start