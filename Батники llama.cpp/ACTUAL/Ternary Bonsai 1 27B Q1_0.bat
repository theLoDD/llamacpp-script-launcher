Rem #################################
Rem ## Begin of user-editable part ##
Rem #################################

cd "C:\LOCALNET\llama.cpp\llama-prism-b12128-d7b2896-bin-win-cuda-12.4-x64"
setlocal enableDelayedExpansion
set "PATHER=C:\LOCALNET\LLM_Models\Qwen3.6\Bonsai-27B-Q1_0.gguf"

Rem #################################
Rem ##  End of user-editable part  ##
Rem #################################

llama-server.exe ^
	-t 8 ^
    -lv 4 ^
	--jinja ^
	--chat-template-file "C:\LOCALNET\llama.cpp\chat_template.jinja" ^
    --model !PATHER! ^
    --ui-mcp-proxy ^
    --host 0.0.0.0 ^
    --port 8081 ^
    --flash-attn on ^
    --fit off ^
    --seed 42 ^
    --n-gpu-layers 999 ^
    --ctx-size 54784 ^
    --batch-size 1536 ^
    --ubatch-size 1024 ^
    --parallel 1 ^
    --load-mode none ^
    --temp 0.6 ^
    --top-p 0.95 ^
    --top-k 20 ^
    --min-p 0.00 ^
    --presence-penalty 0.0 ^
    --repeat-penalty 1.0 ^
    --reasoning-budget 0 ^
	-ctk q8_0 ^
	-ctv q8_0
	
pause