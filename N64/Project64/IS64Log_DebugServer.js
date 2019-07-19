//IS-Viewer 64 Message Register Emulation script by LuigiBlood
//This version uses this Node Package: https://github.com/MNGoldenEagle/DebugConsole

var debugServer = new Server({port:411});
var socket = null;

debugServer.on('connection', function(newSocket) {
	socket = newSocket;
	
	newSocket.on('close', function() {
		socket = null;
	});
});

console.log("IS-Viewer (Debug Server)");

//const _IS_MSGBUFFER_AD =  0xb1ff0000;
const _IS_MSGBUFFER_AD =  0xb3ff0000;
const _IS_MSGBUFFER_LEN = 0x10000;
const _IS_MSGBUF_HEADLEN = 0x20;
const _IS_MSGBUFFER_AD_END =  _IS_MSGBUFFER_AD+_IS_MSGBUFFER_LEN;
const _IS_MSGBUF_CHKAD =  _IS_MSGBUFFER_AD+0x00;
const _IS_MSGBUF_GETPT =  _IS_MSGBUFFER_AD+0x04;
const _IS_MSGBUF_PUTPT =  _IS_MSGBUFFER_AD+0x14;
const _IS_MSGBUF_MSGTOP = _IS_MSGBUFFER_AD+_IS_MSGBUF_HEADLEN;
const _IS_MSGBUF_MSGLEN = _IS_MSGBUF_HEADLEN-_IS_MSGBUF_HEADLEN;

const ADDR_IS64_REG = new AddressRange(_IS_MSGBUFFER_AD, _IS_MSGBUF_MSGTOP);
const ADDR_IS64_MSG = new AddressRange(_IS_MSGBUF_MSGTOP, _IS_MSGBUFFER_AD_END);

//IS64 MSG Registers
var IS_CHKAD = 0x49533634;	//"IS64"
var IS_GETPT = 0;
var IS_PUTPT = 0;
var IS_MSG = new Array(0x10000 - 0x20);

var return_data = 0;
var return_reg = 0;
var callbackId = 0;

events.onread(ADDR_IS64_REG, function(addr) {
	return_reg = getStoreOp();
	return_data = 0;
	if (addr == _IS_MSGBUF_CHKAD)
	{
		return_data = IS_CHKAD;
	}
	else if (addr == _IS_MSGBUF_GETPT)
	{
		return_data = IS_GETPT;
	}
	else if (addr == _IS_MSGBUF_PUTPT)
	{
		return_data = IS_PUTPT;
	}
	
	callbackId = events.onexec((gpr.pc + 4), ReadCartReg);
});

events.onwrite(ADDR_IS64_REG, function(addr) {
	return_reg = getStoreOp();
	if (addr == _IS_MSGBUF_CHKAD)
	{
		IS_CHKAD = getStoreOpValue();
	}
	else if (addr == _IS_MSGBUF_GETPT)
	{
		IS_GETPT = getStoreOpValue();
	}
	else if (addr == _IS_MSGBUF_PUTPT)
	{
		//Handle this output
		OutputString(IS_PUTPT, getStoreOpValue());
		IS_PUTPT = getStoreOpValue();
	}
});

events.onread(ADDR_IS64_MSG, function(addr) {
	return_reg = getStoreOp();
	//Game will use osPiRead at all times so it's 32-bit aligned
	
	var offset = addr - _IS_MSGBUF_MSGTOP;
	
	return_data = ((IS_MSG[offset + 0] & 0xFF) << 24);
	return_data |= ((IS_MSG[offset + 1] & 0xFF) << 16);
	return_data |= ((IS_MSG[offset + 2] & 0xFF) << 8);
	return_data |= ((IS_MSG[offset + 3] & 0xFF) << 0);
	
	callbackId = events.onexec((gpr.pc + 4), ReadCartReg);
});

events.onwrite(ADDR_IS64_MSG, function(addr) {
	return_reg = getStoreOp();
	//Game will use osPiRead at all times so it's 32-bit aligned
	
	var offset = addr - _IS_MSGBUF_MSGTOP;
	var datamsg = getStoreOpValue();
	IS_MSG[offset + 0] = ((datamsg >> 24) & 0xFF);
	IS_MSG[offset + 1] = ((datamsg >> 16) & 0xFF);
	IS_MSG[offset + 2] = ((datamsg >> 8) & 0xFF);
	IS_MSG[offset + 3] = ((datamsg >> 0) & 0xFF);
});

function getStoreOp()
{
	// hacky way to get value that SW will write
	var pcOpcode = mem.u32[gpr.pc];
	var tReg = (pcOpcode >> 16) & 0x1F;
	return tReg;
}

function getStoreOpValue()
{
	// hacky way to get value that SW will write
	var pcOpcode = mem.u32[gpr.pc];
	var tReg = (pcOpcode >> 16) & 0x1F;
	return gpr[tReg];
}

function ReadCartReg()
{
    gpr[return_reg] = return_data;
    events.remove(callbackId);
}

function EmptyMsg()
{
	for (var i = 0; i < IS_MSG.length; i++)
	{
		IS_MSG[i] = 0;
	}
}

function OutputString(start, end)
{
	//Output string
	var stringmsg = [];
	for (var i = start; i != end; i++)
	{
		if (i >= _IS_MSGBUF_MSGLEN)
		{
				i -= _IS_MSGBUF_MSGLEN;
		}
		stringmsg.push(IS_MSG[i]);
	}
	
	socket.write(String.fromCharCode.apply(null, stringmsg));
}

/*! sprintf-js v1.0.3 | Copyright (c) 2007-present, Alexandru Marasteanu <hello@alexei.ro> | BSD-3-Clause */
!function(e){"use strict";function t(){var e=arguments[0],r=t.cache;return r[e]&&r.hasOwnProperty(e)||(r[e]=t.parse(e)),t.format.call(null,r[e],arguments)}function r(e){return"number"==typeof e?"number":"string"==typeof e?"string":Object.prototype.toString.call(e).slice(8,-1).toLowerCase()}function n(e,t){return t>=0&&t<=7&&i[e]?i[e][t]:Array(t+1).join(e)}var s={not_string:/[^s]/,not_bool:/[^t]/,not_type:/[^T]/,not_primitive:/[^v]/,number:/[diefg]/,numeric_arg:/[bcdiefguxX]/,json:/[j]/,not_json:/[^j]/,text:/^[^\x25]+/,modulo:/^\x25{2}/,placeholder:/^\x25(?:([1-9]\d*)\$|\(([^\)]+)\))?(\+)?(0|'[^$])?(-)?(\d+)?(?:\.(\d+))?([b-gijostTuvxX])/,key:/^([a-z_][a-z_\d]*)/i,key_access:/^\.([a-z_][a-z_\d]*)/i,index_access:/^\[(\d+)\]/,sign:/^[\+\-]/};t.format=function(e,a){var i,o,l,p,c,f,u,g=1,_=e.length,d="",b=[],h=!0,x="";for(o=0;o<_;o++)if(d=r(e[o]),"string"===d)b[b.length]=e[o];else if("array"===d){if(p=e[o],p[2])for(i=a[g],l=0;l<p[2].length;l++){if(!i.hasOwnProperty(p[2][l]))throw new Error(t('[sprintf] property "%s" does not exist',p[2][l]));i=i[p[2][l]]}else i=p[1]?a[p[1]]:a[g++];if(s.not_type.test(p[8])&&s.not_primitive.test(p[8])&&"function"==r(i)&&(i=i()),s.numeric_arg.test(p[8])&&"number"!=r(i)&&isNaN(i))throw new TypeError(t("[sprintf] expecting number but found %s",r(i)));switch(s.number.test(p[8])&&(h=i>=0),p[8]){case"b":i=parseInt(i,10).toString(2);break;case"c":i=String.fromCharCode(parseInt(i,10));break;case"d":case"i":i=parseInt(i,10);break;case"j":i=JSON.stringify(i,null,p[6]?parseInt(p[6]):0);break;case"e":i=p[7]?parseFloat(i).toExponential(p[7]):parseFloat(i).toExponential();break;case"f":i=p[7]?parseFloat(i).toFixed(p[7]):parseFloat(i);break;case"g":i=p[7]?parseFloat(i).toPrecision(p[7]):parseFloat(i);break;case"o":i=i.toString(8);break;case"s":i=String(i),i=p[7]?i.substring(0,p[7]):i;break;case"t":i=String(!!i),i=p[7]?i.substring(0,p[7]):i;break;case"T":i=r(i),i=p[7]?i.substring(0,p[7]):i;break;case"u":i=parseInt(i,10)>>>0;break;case"v":i=i.valueOf(),i=p[7]?i.substring(0,p[7]):i;break;case"x":i=parseInt(i,10).toString(16);break;case"X":i=parseInt(i,10).toString(16).toUpperCase()}s.json.test(p[8])?b[b.length]=i:(!s.number.test(p[8])||h&&!p[3]?x="":(x=h?"+":"-",i=i.toString().replace(s.sign,"")),f=p[4]?"0"===p[4]?"0":p[4].charAt(1):" ",u=p[6]-(x+i).length,c=p[6]&&u>0?n(f,u):"",b[b.length]=p[5]?x+i+c:"0"===f?x+c+i:c+x+i)}return b.join("")},t.cache={},t.parse=function(e){for(var t=e,r=[],n=[],a=0;t;){if(null!==(r=s.text.exec(t)))n[n.length]=r[0];else if(null!==(r=s.modulo.exec(t)))n[n.length]="%";else{if(null===(r=s.placeholder.exec(t)))throw new SyntaxError("[sprintf] unexpected placeholder");if(r[2]){a|=1;var i=[],o=r[2],l=[];if(null===(l=s.key.exec(o)))throw new SyntaxError("[sprintf] failed to parse named argument key");for(i[i.length]=l[1];""!==(o=o.substring(l[0].length));)if(null!==(l=s.key_access.exec(o)))i[i.length]=l[1];else{if(null===(l=s.index_access.exec(o)))throw new SyntaxError("[sprintf] failed to parse named argument key");i[i.length]=l[1]}r[2]=i}else a|=2;if(3===a)throw new Error("[sprintf] mixing positional and named placeholders is not (yet) supported");n[n.length]=r}t=t.substring(r[0].length)}return n};var a=function(e,r,n){return n=(r||[]).slice(0),n.splice(0,0,e),t.apply(null,n)},i={0:["","0","00","000","0000","00000","000000","0000000"]," ":[""," ","  ","   ","    ","     ","      ","       "],_:["","_","__","___","____","_____","______","_______"]};"undefined"!=typeof exports&&(exports.sprintf=t,exports.vsprintf=a),"undefined"!=typeof e&&(e.sprintf=t,e.vsprintf=a,"function"==typeof define&&define.amd&&define(function(){return{sprintf:t,vsprintf:a}}))}("undefined"==typeof window?this:window);
//# sourceMappingURL=sprintf.min.js.map