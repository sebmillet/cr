#!/bin/sh

./conv.sh conv-input1.adoc conv-input1.html
md5sum conv-input1.md
md5sum conv-input1-ref.md

