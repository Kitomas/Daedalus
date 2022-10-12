#cc65 version of clipper
deleteOriginal=False
from sys import argv
from os import remove, system
from os.path import exists,abspath as resolvePath
from time import sleep
import subprocess

output="NROM_OUTPUT.nes"
sources=[
"main.c",
"mylib.s",
]

argv=[None,
"cl65.exe",#"-O", #-O=optimize
"-l","asmlistout.txt",
"-m","mapfileout.txt","-vm",
"-t","none",
"-C","my_nes.cfg",
"-o",output] + sources

#argv=[None,"cc65.exe","-o","mainout.s","main.c"]
system("cls")
print(" ".join(argv[1:]))
#subprocess.run(argv[1:])
proc=subprocess.Popen(argv[1:], stdout=subprocess.PIPE, shell=True)
while proc.poll() == None: sleep(0.2)
pExitCode=proc.poll()
pOutput,pError = proc.communicate()
if len(pOutput) != 0: print(pOutput.decode("utf-8"))
if pExitCode != 0: exit()

'''
if deleteOriginal:
    if exists(resolvePath(argv[-2])):
      remove(resolvePath(argv[-2]))
    else:
      print('"{}" is missing! deletion skipped'.format(resolvePath(argv[-2])))
'''