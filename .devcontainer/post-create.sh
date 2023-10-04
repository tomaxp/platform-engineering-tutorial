#!/bin/bash

echo "post-create start" >> ~/status

# this runs in background after UI is available
# add your commands here

echo alias k=kubectl >> /home/vscode/.zshrc

echo "post-create complete" >> ~/status