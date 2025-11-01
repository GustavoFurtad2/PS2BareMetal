# PS2BareMetal

# About

This is a repository with bare metal projects for the Playstation 2 that uses [naken asm](https://github.com/mikeakohn/naken_asm) as assembler, here are projects that I made to learn about how the console works.

Not all projects will be fully documented. Project 1 - Triangle is well documented because, after assembly 6502, it's the first MIPS assembly I'm learning, and I want readers to learn almost everything about MIPS by looking at this code. In other projects like projects 2, 3, 4... the code presented in the previous project will not be commented on; only new code sections not yet presented or important information will be included. So, whether you're very experienced or not, if you don't have knowledge of the Playstation 2, I recommend you view each project in sequential order (project 1, 2, 3...).

# How to compile

You will need the downloaded naked_asm, and configure it in the makefile, and run the compilation command ```make PROJECT_FOLDER=folder``` if you want to compile the "1-triangle" example, then you should write: ```make PROJECT_FOLDER=1-triangle```