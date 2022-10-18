console.log("Mario Artist Talent Studio - SFX Suppress");
//This was made to rip music without any SFX on the way.
//Talent Studio Mode:
//801C0374 (Var) - Music Mode (0 to 4)
//801695D0 (Func)- Function to change song effect (0 = Loud, 1 = Slow, 2 = Fast, 3 = Normal)
//Movie Studio Mode:
//801C0378 (Var) - Music Mode (0 to 4)

console.log("SongEffectMode, TalentMusicMode, MovieMusicMode");
var SongEffectMode = 0;
var TalentMusicMode = 0;
var MovieMusicMode = 0;

//FIFO Sound
events.onexec(0x80158918, function(addr)
{
    if ((cpu.gpr.a0 & 0xFF000000) == 0x06000000)
    {
	//Skip to the end of the routine
        cpu.pc = 0x80158978;
    }
})

//Force Song Effect
events.onexec(0x80169C5C, function(addr)
{
    cpu.gpr.a0 = SongEffectMode;
})

//Force Music Mode
events.onexec(0x80169D94, function(addr)
{
    mem.u32[0x801C0374] = TalentMusicMode;
    mem.u32[0x801C0378] = MovieMusicMode;
})
