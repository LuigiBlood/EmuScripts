console.clear();

const STR = "LSFS";
console.log("- Rare Security - (" + STR + ")");

const ADDR_RARE = new AddressRange(0xBC000000, 0xBC000004-1);
var RARE_BUF = new Buffer(STR);

var CartMapper = require("CartMapper.js");
CartMapper.init();
CartMapper.verbose(0);

CartMapper.add(ADDR_RARE, RARE_BUF, null);
