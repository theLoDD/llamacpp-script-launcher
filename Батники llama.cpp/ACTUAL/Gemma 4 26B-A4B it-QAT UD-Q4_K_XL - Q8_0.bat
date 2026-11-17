Rem #################################
Rem ## Begin of user-editable part ##
Rem #################################
cd "C:\LOCALNET\llama.cpp\llama-b12387-bin-win-cuda-12.4-x64"

setlocal enableDelayedExpansion

set "PATHER=C:\LOCALNET\LLM_Models\Gemma_4\gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf"
set "MTP=C:\LOCALNET\LLM_Models\Gemma_4\gemma-4-26B-A4B-it-Q4_0-MTP.gguf"

Rem #################################
Rem ##  End of user-editable part  ##
Rem #################################

llama-server.exe ^
    -lv 4 ^
	--jinja ^
	--chat-template-file "C:\LOCALNET\llama.cpp\chat_template_gemma.jinja" ^
    --model !PATHER! ^
    --host 0.0.0.0 ^
    --port 8081 ^
    --flash-attn on ^
    --fit off ^
    --seed 42 ^
    --n-gpu-layers 999 ^
    --ctx-size 251904 ^
    --batch-size 1280 ^
    --ubatch-size 1024 ^
    --parallel 1 ^
    --n-cpu-moe 31 ^
	-t 12 ^
    --load-mode none ^
    --temp 1.0 ^
    --top-p 0.95 ^
	--reasoning-budget 0 ^
    --top-k 64 ^
    --min-p 0.00 ^
	-ctk q8_0 ^
	-ctv q8_0 ^
    --spec-type draft-mtp ^
    --spec-draft-n-max 2
	
pause