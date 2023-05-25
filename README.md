# FT-991A-Commander
A **very** rudimentary Yaesu FT-991/A status monitor using the CAT interface. Also implements protection lowering TX power if HI SWR is spotted.

Also: Dumps and restores the radio configuration and memories via the `--backup` or `--restore` parameters.

# Yaesu FT-991A SPR and SPW utilities
A **very** powerful tool that can other than **permanently destroy and brick your expensive transceiver**; read and directly write memory segments of the FT-991A, virtually allowing to control every aspect of the radio - even without a standard CAT command. Proceed at your own risk.

[Gil Kloepfer](https://www.qrz.com/db/KI5BPK) [mapped](https://www.kloepfer.org/ft991a/memory-map.txt) the FT-991 address space, and by reading content (and carefully writing memory segments), you can extend significantly the control possibilities if your FT-991A.

## SPR
The `spr.sh` tool reads **two bytes** from a given memory address. You might need to edit the script and change the serial port configuration. Specify the address to be read as the only argument. The value is hexadecimal and **must contain 4 characters**.

### Example
To read the `012A` memory address:
~~~
./spr.sh 012A
~~~

Notice that SPR returns two bytes. On the above example you got the result from 012A to 012B. For a next contiguous read, do a `spr.sh` to the address 012C and so forth.

## SPW
The `spw.sh` tool is the risky one - it comes disabled by default and will spit an error message at the first time you try to use it out-of-the-box. Check the shell script and find out what has to be changed in order to make it effective - Also, configure the serial port.

It writes **two bytes** in a given memory address. This command takes two arguments: The first argument is the memory address, and the second argument is the value to be written. All values are hexadecimal and **must contain 4 characters** - in hexadecimal notation.

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

Now open a second console, and read the `012A` address space contents. **HINT:** Run it twice, so the result can show on the other terminal.

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

Be careful, take note of the values and remember that any typo can be **fatal**. The provided code has no safeguards.

Happy hacking!

## Using it on Windows
I wanted some commands to set the encoder mode to `CH-DIAL` mode while in VFO mode, and `MCH` mode while in memory mode - [so I could use it](https://github.com/rfrht/Voicemeeter-FT-991A/commit/298445b72fac669dde69d7dbf635612c3fad2dfe) in my VoiceMeeter automation.

The first step was to find out the memory address. For VFO mode, it's the address `0149`. The `CH-DIAL` memory value is `1f`. So, by running `./spw.sh 0149 1f1f` I got this sequence:

~~~
53 50 57 01 49 1f 1f 82 3b
~~~

Now - let's create a binary file containing this sequence on the Windows machine. Open your `cmd` prompt and type:

~~~
>ch-dial.txt echo(53 50 57 01 49 1f 1f 82 3b
~~~

Yes - the command starts with an `>` and the echo command **doesn't have** a closing parenthesis. Next step, let's convert it to a binary file using the `certutil` tool:

~~~
certutil -decodehex ch-dial.txt ch-dial.bin
~~~

That will result in a short file named `ch-dial.bin`. You can validate its content by viewing its content using `type ch-dial.bin`. The file should contain a SPW, a happy face, I, two arrows down, é and semicolon.

Now it's time to send it to the radio. Suppose your COM port is `COM7`, 38,400 bps, set the COM port:

~~~
mode COM7 BAUD=38400 PARITY=n DATA=8
~~~

Put your radio on VFO mode, and hit a different button **other than** `CH-DIAL` on your radio, such as, `MIC GAIN`. Your encoder at this point should be commanding the microphone gain. And then type:

~~~
type ch-dial.bin > COM7
~~~

Then the magic should happen: Your encoder should move to the `CH-DIAL` mode.

A final nugget, setting the encoder to `MCH` mode when in **MEMORY** mode. This is the code:

~~~
>mch.txt echo(53 50 57 01 4e 35 35 b3 3b
~~~

Encode it:

~~~
certutil -decodehex mch.txt mch.bin
~~~

And then put it to run. Move the radio to Memory mode, select any other encoder function than `MCH`, and finally:

~~~
type mch.bin > COM7
~~~

And your encoder will flip to MCH mode.

![yay!](https://rf3.org:8443/q/wink-spr.png)
