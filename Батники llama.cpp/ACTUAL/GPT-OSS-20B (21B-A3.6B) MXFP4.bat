Rem #################################
Rem ## Begin of user-editable part ##
Rem #################################

cd "C:\LOCALNET\llama.cpp\llama-b10330-bin-win-cuda-12.4-x64"

setlocal enableDelayedExpansion

set "PATHER=C:\LOCALNET\LLM_Models\GPT-OSS-20B\gpt-oss-20b-MXFP4.gguf"

Rem #################################
Rem ##  End of user-editable part  ##
Rem #################################

llama-server.exe ^
    --mlock ^
    -lv 4 ^
	--jinja ^
    --model !PATHER! ^
    --host 0.0.0.0 ^
    --port 8081 ^
    --flash-attn on ^
    --fit off ^
    --seed 42 ^
    --n-gpu-layers 999 ^
    --ctx-size 131072 ^
    --batch-size 1536 ^
    --ubatch-size 1536 ^
    --parallel 1 ^
    --n-cpu-moe 25 ^
	-t 12 ^
    --load-mode none ^
    --temp 0.8 ^
    --top-p 0.95 ^
    --top-k 40 ^
    --min-p 0.00 ^
	--cache-type-k f16 ^
    --cache-type-v f16
	
pause