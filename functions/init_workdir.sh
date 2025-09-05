#!/bin/bash

# 初始化工作目录
init_workdir() {
  echo "Initializing work directory..."
  mkdir -p /data/software
  cd /data/software
  echo "Work directory initialized."
}