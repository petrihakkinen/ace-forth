#!/bin/sh

cd ..
#./compile.lua -o test/starfield.tap -l test/starfield.lst --filename stars --main stars --mcode --optimize test/starfield.f

./compile.lua -o test/mcode.tap -l test/mcode.lst --filename main --main main --mcode --optimize test/mcode.f