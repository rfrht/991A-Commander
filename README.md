# FT-991A-Commander
A **very** rudimentary FT-991 status monitor using the CAT interface. Also implements protection lowering TX power if HI SWR is spotted.

Also: Dumps and restores the radio configuration and memories via the `--backup` or `--restore` parameters.

# SPR and SPW utilities
A **very** powerful tool that can other than **permanently destroy and brick your expensive transceiver**; read and directly write memory segments of the FT-991A, virtually allowing to control every aspect of the radio - even without a standard CAT command. Proceed at your own risk.

[Gil Kloepfer](https://www.qrz.com/db/KI5BPK) [mapped](https://www.kloepfer.org/ft991a/memory-map.txt) the FT-991 address space, and by reading content (and carefully writing memory segments), you can extend significantly the control possibilities if your FT-991A.

## SPR
The `spr.sh` tool reads the content from a given memory address. Specify the address to be read as the only argument. The value is hexadecimal and **must contain 4 characters**.

### Example
To read the `012A` memory address:
~~~
./spr.sh 012A
~~~

## SPW
The `spw.sh` tool writes two bytes in a given memory address. This command takes two arguments: The first argument is the memory address, and the second argument is the value to be written. All values are hexadecimal and **must contain 4 characters**.

### Example
To write 0073 to address 012A:
~~~
./spw.sh 012a 0073
~~~

## How to use the tools
**FIRST**, give a good read on the Gil's [memory map](https://www.kloepfer.org/ft991a/memory-map.txt). When you find something interesting, then first read the memory segment. Take note of the result. In this example, we will switch the 991A's screen from scope to the buttons/function display - something that's not possible using CAT.

By reading Gil's map, we can see that the screen mode is defined on address `012A`. So the first thing, attach a `cat` to the Serial USB port:

~~~
[root@rf ~]# cat /dev/ttyUSB0 | hexdump -C -n 9
~~~

Now open a second console, and read the `012A` address space contents:

~~~
[root@rf 991a-commander]# ./spr.sh 012A
00000000  53 50 52 01 2a 20 3b                              |SPR.* ;|
00000007
~~~

If you are on the Scope/Waterfall mode, you will get this result:

~~~
[root@rf ~]# cat /dev/ttyUSB0 | hexdump -C -n 9
00000000  53 50 52 01 2a 00 73 93  3b                       |SPR.*.s.;|
00000009
~~~

So you just learned that in the scope mode, the memory address `012A` has the values `0073`. Ctrl-C the console and start it over. Push the F M-List and put the radio on Buttons/functionality mode. Read it using the `spr.sh 012A` command again. Then, you will get this result:

~~~
[root@rf ~]# cat /dev/ttyUSB0 | hexdump -C -n 9
00000000  53 50 52 01 2a 80 73 13  3b                       |SPR.*.s.;|
00000009
~~~

So, for the button/functionality mode, the address `012A` has the value `8073`. Now it is time to go bold. You will now change the screen mode (back to waterfall) by writing the memory content.

Run `./spw.sh 012a 0073` - That should do the magic and put your radio on the waterfall mode

~~~
[root@rf 991a-commander]# ./spw.sh 012a 0073
00000000  53 50 57 01 2a 00 73 98  3b                       |SPW.*.s.;|
00000009
~~~

And conversely, to recall the buttons mode, use `./spw.sh 012a 8073`

Be careful, take note of the values and remember that any typo can be **fatal**.

Happy hacking!
