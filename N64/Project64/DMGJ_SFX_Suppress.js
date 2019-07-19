console.log("Mario Artist Polygon Studio - SFX Suppress");
//This was made to rip music without any SFX on the way.

//FIFO Sound
events.onexec(0x8003F960, function(addr)
{
    if ((gpr.a0 & 0xFF000000) == 0x06000000)
    {
        gpr.a0 = 0x03000000;
    }
})
