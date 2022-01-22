return { 
	[0x00] = "NOP",
	[0x01] = { nn = { nn = "LD BC,nn" } },
	[0x02] = "LD (BC),A",
	[0x03] = "INC BC",
	[0x04] = "INC B",
	[0x05] = "DEC B",
	[0x06] = { n = "LD B,n" },
	[0x07] = "RLCA",
	[0x08] = "EX AF,AF'",
	[0x09] = "ADD HL,BC",
	[0x0a] = "LD A,(BC)",
	[0x0b] = "DEC BC",
	[0x0c] = "INC C",
	[0x0d] = "DEC C",
	[0x0e] = { n = "LD C,n" },
	[0x0f] = "RRCA",
	[0x10] = { o = "DJNZ o" },
	[0x11] = { nn = { nn = "LD DE,nn" } },
	[0x12] = "LD (DE),A",
	[0x13] = "INC DE",
	[0x14] = "INC D",
	[0x15] = "DEC D",
	[0x16] = { n = "LD D,n" },
	[0x17] = "RLA",
	[0x18] = { o = "JR o" },
	[0x19] = "ADD HL,DE",
	[0x1a] = "LD A,(DE)",
	[0x1b] = "DEC DE",
	[0x1c] = "INC E",
	[0x1d] = "DEC E",
	[0x1e] = { n = "LD E,n" },
	[0x1f] = "RRA",
	[0x20] = { o = "JR NZ,o" },
	[0x21] = { nn = { nn = "LD HL,nn" } },
	[0x22] = { nn = { nn = "LD (nn),HL" } },
	[0x23] = "INC HL",
	[0x24] = "INC H",
	[0x25] = "DEC H",
	[0x26] = { n = "LD H,n" },
	[0x27] = "DAA",
	[0x28] = { o = "JR Z,o" },
	[0x29] = "ADD HL,HL",
	[0x2a] = { nn = { nn = "LD HL,(nn)" } },
	[0x2b] = "DEC HL",
	[0x2c] = "INC L",
	[0x2d] = "DEC L",
	[0x2e] = { n = "LD L,n" },
	[0x2f] = "CPL",
	[0x30] = { o = "JR NC,o" },
	[0x31] = { nn = { nn = "LD SP,nn" } },
	[0x32] = { nn = { nn = "LD (nn),A" } },
	[0x33] = "INC SP",
	[0x34] = "INC (HL)",
	[0x35] = "DEC (HL)",
	[0x36] = { n = "LD (HL),n" },
	[0x37] = "SCF",
	[0x38] = { o = "JR C,o" },
	[0x39] = "ADD HL,SP",
	[0x3a] = { nn = { nn = "LD A,(nn)" } },
	[0x3b] = "DEC SP",
	[0x3c] = "INC A",
	[0x3d] = "DEC A",
	[0x3e] = { n = "LD A,n" },
	[0x3f] = "CCF",
	[0x40] = "LD B,B",
	[0x41] = "LD B,C",
	[0x42] = "LD B,D",
	[0x43] = "LD B,E",
	[0x44] = "LD B,H",
	[0x45] = "LD B,L",
	[0x46] = "LD B,(HL)",
	[0x47] = "LD B,A",
	[0x48] = "LD C,B",
	[0x49] = "LD C,C",
	[0x4a] = "LD C,D",
	[0x4b] = "LD C,E",
	[0x4c] = "LD C,H",
	[0x4d] = "LD C,L",
	[0x4e] = "LD C,(HL)",
	[0x4f] = "LD C,A",
	[0x50] = "LD D,B",
	[0x51] = "LD D,C",
	[0x52] = "LD D,D",
	[0x53] = "LD D,E",
	[0x54] = "LD D,H",
	[0x55] = "LD D,L",
	[0x56] = "LD D,(HL)",
	[0x57] = "LD D,A",
	[0x58] = "LD E,B",
	[0x59] = "LD E,C",
	[0x5a] = "LD E,D",
	[0x5b] = "LD E,E",
	[0x5c] = "LD E,H",
	[0x5d] = "LD E,L",
	[0x5e] = "LD E,(HL)",
	[0x5f] = "LD E,A",
	[0x60] = "LD H,B",
	[0x61] = "LD H,C",
	[0x62] = "LD H,D",
	[0x63] = "LD H,E",
	[0x64] = "LD H,H",
	[0x65] = "LD H,L",
	[0x66] = "LD H,(HL)",
	[0x67] = "LD H,A",
	[0x68] = "LD L,B",
	[0x69] = "LD L,C",
	[0x6a] = "LD L,D",
	[0x6b] = "LD L,E",
	[0x6c] = "LD L,H",
	[0x6d] = "LD L,L",
	[0x6e] = "LD L,(HL)",
	[0x6f] = "LD L,A",
	[0x70] = "LD (HL),B",
	[0x71] = "LD (HL),C",
	[0x72] = "LD (HL),D",
	[0x73] = "LD (HL),E",
	[0x74] = "LD (HL),H",
	[0x75] = "LD (HL),L",
	[0x76] = "HALT",
	[0x77] = "LD (HL),A",
	[0x78] = "LD A,B",
	[0x79] = "LD A,C",
	[0x7a] = "LD A,D",
	[0x7b] = "LD A,E",
	[0x7c] = "LD A,H",
	[0x7d] = "LD A,L",
	[0x7e] = "LD A,(HL)",
	[0x7f] = "LD A,A",
	[0x80] = "ADD A,B",
	[0x81] = "ADD A,C",
	[0x82] = "ADD A,D",
	[0x83] = "ADD A,E",
	[0x84] = "ADD A,H",
	[0x85] = "ADD A,L",
	[0x86] = "ADD A,(HL)",
	[0x87] = "ADD A,A",
	[0x88] = "ADC A,B",
	[0x89] = "ADC A,C",
	[0x8a] = "ADC A,D",
	[0x8b] = "ADC A,E",
	[0x8c] = "ADC A,H",
	[0x8d] = "ADC A,L",
	[0x8e] = "ADC A,(HL)",
	[0x8f] = "ADC A,A",
	[0x90] = "SUB B",
	[0x91] = "SUB C",
	[0x92] = "SUB D",
	[0x93] = "SUB E",
	[0x94] = "SUB H",
	[0x95] = "SUB L",
	[0x96] = "SUB (HL)",
	[0x97] = "SUB A",
	[0x98] = "SBC A,B",
	[0x99] = "SBC A,C",
	[0x9a] = "SBC A,D",
	[0x9b] = "SBC A,E",
	[0x9c] = "SBC A,H",
	[0x9d] = "SBC A,L",
	[0x9e] = "SBC A,(HL)",
	[0x9f] = "SBC A,A",
	[0xa0] = "AND B",
	[0xa1] = "AND C",
	[0xa2] = "AND D",
	[0xa3] = "AND E",
	[0xa4] = "AND H",
	[0xa5] = "AND L",
	[0xa6] = "AND (HL)",
	[0xa7] = "AND A",
	[0xa8] = "XOR B",
	[0xa9] = "XOR C",
	[0xaa] = "XOR D",
	[0xab] = "XOR E",
	[0xac] = "XOR H",
	[0xad] = "XOR L",
	[0xae] = "XOR (HL)",
	[0xaf] = "XOR A",
	[0xb0] = "OR B",
	[0xb1] = "OR C",
	[0xb2] = "OR D",
	[0xb3] = "OR E",
	[0xb4] = "OR H",
	[0xb5] = "OR L",
	[0xb6] = "OR (HL)",
	[0xb7] = "OR A",
	[0xb8] = "CP B",
	[0xb9] = "CP C",
	[0xba] = "CP D",
	[0xbb] = "CP E",
	[0xbc] = "CP H",
	[0xbd] = "CP L",
	[0xbe] = "CP (HL)",
	[0xbf] = "CP A",
	[0xc0] = "RET NZ",
	[0xc1] = "POP BC",
	[0xc2] = { nn = { nn = "JP NZ,nn" } },
	[0xc3] = { nn = { nn = "JP nn" } },
	[0xc4] = { nn = { nn = "CALL NZ,nn" } },
	[0xc5] = "PUSH BC",
	[0xc6] = { n = "ADD A,n" },
	[0xc7] = "RST 0",
	[0xc8] = "RET Z",
	[0xc9] = "RET",
	[0xca] = { nn = { nn = "JP Z,nn" } },
	[0xcb] = { 
		[0x00] = "RLC B",
		[0x01] = "RLC C",
		[0x02] = "RLC D",
		[0x03] = "RLC E",
		[0x04] = "RLC H",
		[0x05] = "RLC L",
		[0x06] = "RLC (HL)",
		[0x07] = "RLC A",
		[0x08] = "RRC B",
		[0x09] = "RRC C",
		[0x0a] = "RRC D",
		[0x0b] = "RRC E",
		[0x0c] = "RRC H",
		[0x0d] = "RRC L",
		[0x0e] = "RRC (HL)",
		[0x0f] = "RRC A",
		[0x10] = "RL B",
		[0x11] = "RL C",
		[0x12] = "RL D",
		[0x13] = "RL E",
		[0x14] = "RL H",
		[0x15] = "RL L",
		[0x16] = "RL (HL)",
		[0x17] = "RL A",
		[0x18] = "RR B",
		[0x19] = "RR C",
		[0x1a] = "RR D",
		[0x1b] = "RR E",
		[0x1c] = "RR H",
		[0x1d] = "RR L",
		[0x1e] = "RR (HL)",
		[0x1f] = "RR A",
		[0x20] = "SLA B",
		[0x21] = "SLA C",
		[0x22] = "SLA D",
		[0x23] = "SLA E",
		[0x24] = "SLA H",
		[0x25] = "SLA L",
		[0x26] = "SLA (HL)",
		[0x27] = "SLA A",
		[0x28] = "SRA B",
		[0x29] = "SRA C",
		[0x2a] = "SRA D",
		[0x2b] = "SRA E",
		[0x2c] = "SRA H",
		[0x2d] = "SRA L",
		[0x2e] = "SRA (HL)",
		[0x2f] = "SRA A",
		[0x38] = "SRL B",
		[0x39] = "SRL C",
		[0x3a] = "SRL D",
		[0x3b] = "SRL E",
		[0x3c] = "SRL H",
		[0x3d] = "SRL L",
		[0x3e] = "SRL (HL)",
		[0x3f] = "SRL A",
		[0x40] = "BIT 0,B",
		[0x41] = "BIT 0,C",
		[0x42] = "BIT 0,D",
		[0x43] = "BIT 0,E",
		[0x44] = "BIT 0,H",
		[0x45] = "BIT 0,L",
		[0x46] = "BIT 0,(HL)",
		[0x47] = "BIT 0,A",
		[0x48] = "BIT 1,B",
		[0x49] = "BIT 1,C",
		[0x4a] = "BIT 1,D",
		[0x4b] = "BIT 1,E",
		[0x4c] = "BIT 1,H",
		[0x4d] = "BIT 1,L",
		[0x4e] = "BIT 1,(HL)",
		[0x4f] = "BIT 1,A",
		[0x50] = "BIT 2,B",
		[0x51] = "BIT 2,C",
		[0x52] = "BIT 2,D",
		[0x53] = "BIT 2,E",
		[0x54] = "BIT 2,H",
		[0x55] = "BIT 2,L",
		[0x56] = "BIT 2,(HL)",
		[0x57] = "BIT 2,A",
		[0x58] = "BIT 3,B",
		[0x59] = "BIT 3,C",
		[0x5a] = "BIT 3,D",
		[0x5b] = "BIT 3,E",
		[0x5c] = "BIT 3,H",
		[0x5d] = "BIT 3,L",
		[0x5e] = "BIT 3,(HL)",
		[0x5f] = "BIT 3,A",
		[0x60] = "BIT 4,B",
		[0x61] = "BIT 4,C",
		[0x62] = "BIT 4,D",
		[0x63] = "BIT 4,E",
		[0x64] = "BIT 4,H",
		[0x65] = "BIT 4,L",
		[0x66] = "BIT 4,(HL)",
		[0x67] = "BIT 4,A",
		[0x68] = "BIT 5,B",
		[0x69] = "BIT 5,C",
		[0x6a] = "BIT 5,D",
		[0x6b] = "BIT 5,E",
		[0x6c] = "BIT 5,H",
		[0x6d] = "BIT 5,L",
		[0x6e] = "BIT 5,(HL)",
		[0x6f] = "BIT 5,A",
		[0x70] = "BIT 6,B",
		[0x71] = "BIT 6,C",
		[0x72] = "BIT 6,D",
		[0x73] = "BIT 6,E",
		[0x74] = "BIT 6,H",
		[0x75] = "BIT 6,L",
		[0x76] = "BIT 6,(HL)",
		[0x77] = "BIT 6,A",
		[0x78] = "BIT 7,B",
		[0x79] = "BIT 7,C",
		[0x7a] = "BIT 7,D",
		[0x7b] = "BIT 7,E",
		[0x7c] = "BIT 7,H",
		[0x7d] = "BIT 7,L",
		[0x7e] = "BIT 7,(HL)",
		[0x7f] = "BIT 7,A",
		[0x80] = "RES 0,B",
		[0x81] = "RES 0,C",
		[0x82] = "RES 0,D",
		[0x83] = "RES 0,E",
		[0x84] = "RES 0,H",
		[0x85] = "RES 0,L",
		[0x86] = "RES 0,(HL)",
		[0x87] = "RES 0,A",
		[0x88] = "RES 1,B",
		[0x89] = "RES 1,C",
		[0x8a] = "RES 1,D",
		[0x8b] = "RES 1,E",
		[0x8c] = "RES 1,H",
		[0x8d] = "RES 1,L",
		[0x8e] = "RES 1,(HL)",
		[0x8f] = "RES 1,A",
		[0x90] = "RES 2,B",
		[0x91] = "RES 2,C",
		[0x92] = "RES 2,D",
		[0x93] = "RES 2,E",
		[0x94] = "RES 2,H",
		[0x95] = "RES 2,L",
		[0x96] = "RES 2,(HL)",
		[0x97] = "RES 2,A",
		[0x98] = "RES 3,B",
		[0x99] = "RES 3,C",
		[0x9a] = "RES 3,D",
		[0x9b] = "RES 3,E",
		[0x9c] = "RES 3,H",
		[0x9d] = "RES 3,L",
		[0x9e] = "RES 3,(HL)",
		[0x9f] = "RES 3,A",
		[0xa0] = "RES 4,B",
		[0xa1] = "RES 4,C",
		[0xa2] = "RES 4,D",
		[0xa3] = "RES 4,E",
		[0xa4] = "RES 4,H",
		[0xa5] = "RES 4,L",
		[0xa6] = "RES 4,(HL)",
		[0xa7] = "RES 4,A",
		[0xa8] = "RES 5,B",
		[0xa9] = "RES 5,C",
		[0xaa] = "RES 5,D",
		[0xab] = "RES 5,E",
		[0xac] = "RES 5,H",
		[0xad] = "RES 5,L",
		[0xae] = "RES 5,(HL)",
		[0xaf] = "RES 5,A",
		[0xb0] = "RES 6,B",
		[0xb1] = "RES 6,C",
		[0xb2] = "RES 6,D",
		[0xb3] = "RES 6,E",
		[0xb4] = "RES 6,H",
		[0xb5] = "RES 6,L",
		[0xb6] = "RES 6,(HL)",
		[0xb7] = "RES 6,A",
		[0xb8] = "RES 7,B",
		[0xb9] = "RES 7,C",
		[0xba] = "RES 7,D",
		[0xbb] = "RES 7,E",
		[0xbc] = "RES 7,H",
		[0xbd] = "RES 7,L",
		[0xbe] = "RES 7,(HL)",
		[0xbf] = "RES 7,A",
		[0xc0] = "SET 0,B",
		[0xc1] = "SET 0,C",
		[0xc2] = "SET 0,D",
		[0xc3] = "SET 0,E",
		[0xc4] = "SET 0,H",
		[0xc5] = "SET 0,L",
		[0xc6] = "SET 0,(HL)",
		[0xc7] = "SET 0,A",
		[0xc8] = "SET 1,B",
		[0xc9] = "SET 1,C",
		[0xca] = "SET 1,D",
		[0xcb] = "SET 1,E",
		[0xcc] = "SET 1,H",
		[0xcd] = "SET 1,L",
		[0xce] = "SET 1,(HL)",
		[0xcf] = "SET 1,A",
		[0xd0] = "SET 2,B",
		[0xd1] = "SET 2,C",
		[0xd2] = "SET 2,D",
		[0xd3] = "SET 2,E",
		[0xd4] = "SET 2,H",
		[0xd5] = "SET 2,L",
		[0xd6] = "SET 2,(HL)",
		[0xd7] = "SET 2,A",
		[0xd8] = "SET 3,B",
		[0xd9] = "SET 3,C",
		[0xda] = "SET 3,D",
		[0xdb] = "SET 3,E",
		[0xdc] = "SET 3,H",
		[0xdd] = "SET 3,L",
		[0xde] = "SET 3,(HL)",
		[0xdf] = "SET 3,A",
		[0xe0] = "SET 4,B",
		[0xe1] = "SET 4,C",
		[0xe2] = "SET 4,D",
		[0xe3] = "SET 4,E",
		[0xe4] = "SET 4,H",
		[0xe5] = "SET 4,L",
		[0xe6] = "SET 4,(HL)",
		[0xe7] = "SET 4,A",
		[0xe8] = "SET 5,B",
		[0xe9] = "SET 5,C",
		[0xea] = "SET 5,D",
		[0xeb] = "SET 5,E",
		[0xec] = "SET 5,H",
		[0xed] = "SET 5,L",
		[0xee] = "SET 5,(HL)",
		[0xef] = "SET 5,A",
		[0xf0] = "SET 6,B",
		[0xf1] = "SET 6,C",
		[0xf2] = "SET 6,D",
		[0xf3] = "SET 6,E",
		[0xf4] = "SET 6,H",
		[0xf5] = "SET 6,L",
		[0xf6] = "SET 6,(HL)",
		[0xf7] = "SET 6,A",
		[0xf8] = "SET 7,B",
		[0xf9] = "SET 7,C",
		[0xfa] = "SET 7,D",
		[0xfb] = "SET 7,E",
		[0xfc] = "SET 7,H",
		[0xfd] = "SET 7,L",
		[0xfe] = "SET 7,(HL)",
		[0xff] = "SET 7,A" },
	[0xcc] = { nn = { nn = "CALL Z,nn" } },
	[0xcd] = { nn = { nn = "CALL nn" } },
	[0xce] = { n = "ADC A,n" },
	[0xcf] = "RST 8H",
	[0xd0] = "RET NC",
	[0xd1] = "POP DE",
	[0xd2] = { nn = { nn = "JP NC,nn" } },
	[0xd3] = { n = "OUT (n),A" },
	[0xd4] = { nn = { nn = "CALL NC,nn" } },
	[0xd5] = "PUSH DE",
	[0xd6] = { n = "SUB n" },
	[0xd7] = "RST 10H",
	[0xd8] = "RET C",
	[0xd9] = "EXX",
	[0xda] = { nn = { nn = "JP C,nn" } },
	[0xdb] = { n = "IN A,(n)" },
	[0xdc] = { nn = { nn = "CALL C,nn" } },
	[0xdd] = { 
		[0x09] = "ADD IX,BC",
		[0x19] = "ADD IX,DE",
		[0x21] = { nn = { nn = "LD IX,nn" } },
		[0x22] = { nn = { nn = "LD (nn),IX" } },
		[0x23] = "INC IX",
		[0x24] = "INC IXh",
		[0x25] = "DEC IXh",
		[0x26] = { n = "LD IXh,n" },
		[0x29] = "ADD IX,IX",
		[0x2a] = { nn = { nn = "LD IX,(nn)" } },
		[0x2b] = "DEC IX",
		[0x2c] = "INC IXl",
		[0x2d] = "DEC IXl",
		[0x2e] = { n = "LD IXl,n" },
		[0x34] = { o = "INC (IX+o)" },
		[0x35] = { o = "DEC (IX+o)" },
		[0x36] = { o = { n = "LD (IX+o),n" } },
		[0x39] = "ADD IX,SP",
		[0x44] = "LD B,IXh",
		[0x45] = "LD B,IXl",
		[0x46] = { o = "LD B,(IX+o)" },
		[0x4c] = "LD C,IXh",
		[0x4d] = "LD C,IXl",
		[0x4e] = { o = "LD C,(IX+o)" },
		[0x54] = "LD D,IXh",
		[0x55] = "LD D,IXl",
		[0x56] = { o = "LD D,(IX+o)" },
		[0x5c] = "LD E,IXh",
		[0x5d] = "LD E,IXl",
		[0x5e] = { o = "LD E,(IX+o)" },
		[0x64] = "LD IXh,h",
		[0x65] = "LD IXh,l",
		[0x66] = { o = "LD H,(IX+o)" },
		[0x6c] = "LD IXl,h",
		[0x6d] = "LD IXl,l",
		[0x6e] = { o = "LD L,(IX+o)" },
		[0x70] = { o = "LD (IX+o),B" },
		[0x71] = { o = "LD (IX+o),C" },
		[0x72] = { o = "LD (IX+o),D" },
		[0x73] = { o = "LD (IX+o),E" },
		[0x74] = { o = "LD (IX+o),H" },
		[0x75] = { o = "LD (IX+o),L" },
		[0x77] = { o = "LD (IX+o),A" },
		[0x7c] = "LD A,IXh",
		[0x7d] = "LD A,IXl",
		[0x7e] = { o = "LD A,(IX+o)" },
		[0x84] = "ADD A,IXh",
		[0x85] = "ADD A,IXl",
		[0x86] = { o = "ADD A,(IX+o)" },
		[0x8c] = "ADC A,IXh",
		[0x8d] = "ADC A,IXl",
		[0x8e] = { o = "ADC A,(IX+o)" },
		[0x94] = "SUB IXh",
		[0x95] = "SUB IXl",
		[0x96] = { o = "SUB (IX+o)" },
		[0x9c] = "SBC A,IXh",
		[0x9d] = "SBC A,IXl",
		[0x9e] = { o = "SBC A,(IX+o)" },
		[0xa4] = "AND IXh",
		[0xa5] = "AND IXl",
		[0xa6] = { o = "AND (IX+o)" },
		[0xac] = "XOR IXh",
		[0xad] = "XOR IXl",
		[0xae] = { o = "XOR (IX+o)" },
		[0xb4] = "OR IXh",
		[0xb5] = "OR IXl",
		[0xb6] = { o = "OR (IX+o)" },
		[0xbc] = "CP IXh",
		[0xbd] = "CP IXl",
		[0xbe] = { o = "CP (IX+o)" },
		[0xcb] = { o = { 
				[0x06] = "RLC (IX+o)",
				[0x0e] = "RRC (IX+o)",
				[0x16] = "RL (IX+o)",
				[0x1e] = "RR (IX+o)",
				[0x26] = "SLA (IX+o)",
				[0x2e] = "SRA (IX+o)",
				[0x3e] = "SRL (IX+o)",
				[0x46] = "BIT 0,(IX+o)",
				[0x4e] = "BIT 1,(IX+o)",
				[0x56] = "BIT 2,(IX+o)",
				[0x5e] = "BIT 3,(IX+o)",
				[0x66] = "BIT 4,(IX+o)",
				[0x6e] = "BIT 5,(IX+o)",
				[0x76] = "BIT 6,(IX+o)",
				[0x7e] = "BIT 7,(IX+o)",
				[0x86] = "RES 0,(IX+o)",
				[0x8e] = "RES 1,(IX+o)",
				[0x96] = "RES 2,(IX+o)",
				[0x9e] = "RES 3,(IX+o)",
				[0xa6] = "RES 4,(IX+o)",
				[0xae] = "RES 5,(IX+o)",
				[0xb6] = "RES 6,(IX+o)",
				[0xbe] = "RES 7,(IX+o)",
				[0xc6] = "SET 0,(IX+o)",
				[0xce] = "SET 1,(IX+o)",
				[0xd6] = "SET 2,(IX+o)",
				[0xde] = "SET 3,(IX+o)",
				[0xe6] = "SET 4,(IX+o)",
				[0xee] = "SET 5,(IX+o)",
				[0xf6] = "SET 6,(IX+o)",
				[0xfe] = "SET 7,(IX+o)" } },
		[0xe1] = "POP IX",
		[0xe3] = "EX (SP),IX",
		[0xe5] = "PUSH IX",
		[0xe9] = "JP (IX)",
		[0xf9] = "LD SP,IX" },
	[0xde] = { n = "SBC A,n" },
	[0xdf] = "RST 18H",
	[0xe0] = "RET PO",
	[0xe1] = "POP HL",
	[0xe2] = { nn = { nn = "JP PO,nn" } },
	[0xe3] = "EX (SP),HL",
	[0xe4] = { nn = { nn = "CALL PO,nn" } },
	[0xe5] = "PUSH HL",
	[0xe6] = { n = "AND n" },
	[0xe7] = "RST 20H",
	[0xe8] = "RET PE",
	[0xe9] = "JP (HL)",
	[0xea] = { nn = { nn = "JP PE,nn" } },
	[0xeb] = "EX DE,HL",
	[0xec] = { nn = { nn = "CALL PE,nn" } },
	[0xed] = { 
		[0x40] = "IN B,(C)",
		[0x41] = "OUT (C),B",
		[0x42] = "SBC HL,BC",
		[0x43] = { nn = { nn = "LD (nn),BC" } },
		[0x44] = "NEG",
		[0x45] = "RETN",
		[0x46] = "IM 0",
		[0x47] = "LD I,A",
		[0x48] = "IN C,(C)",
		[0x49] = "OUT (C),C",
		[0x4a] = "ADC HL,BC",
		[0x4b] = { nn = { nn = "LD BC,(nn)" } },
		[0x4d] = "RETI",
		[0x4f] = "LD R,A",
		[0x50] = "IN D,(C)",
		[0x51] = "OUT (C),D",
		[0x52] = "SBC HL,DE",
		[0x53] = { nn = { nn = "LD (nn),DE" } },
		[0x56] = "IM 1",
		[0x57] = "LD A,I",
		[0x58] = "IN E,(C)",
		[0x59] = "OUT (C),E",
		[0x5a] = "ADC HL,DE",
		[0x5b] = { nn = { nn = "LD DE,(nn)" } },
		[0x5e] = "IM 2",
		[0x5f] = "LD A,R",
		[0x60] = "IN H,(C)",
		[0x61] = "OUT (C),H",
		[0x62] = "SBC HL,HL",
		[0x67] = "RRD",
		[0x68] = "IN L,(C)",
		[0x69] = "OUT (C),L",
		[0x6a] = "ADC HL,HL",
		[0x6f] = "RLD",
		[0x70] = "IN F,(C)",
		[0x72] = "SBC HL,SP",
		[0x73] = { nn = { nn = "LD (nn),SP" } },
		[0x78] = "IN A,(C)",
		[0x79] = "OUT (C),A",
		[0x7a] = "ADC HL,SP",
		[0x7b] = { nn = { nn = "LD SP,(nn)" } },
		[0xa0] = "LDI",
		[0xa1] = "CPI",
		[0xa2] = "INI",
		[0xa3] = "OUTI",
		[0xa8] = "LDD",
		[0xa9] = "CPD",
		[0xaa] = "IND",
		[0xab] = "OUTD",
		[0xb0] = "LDIR",
		[0xb1] = "CPIR",
		[0xb2] = "INIR",
		[0xb3] = "OTIR",
		[0xb8] = "LDDR",
		[0xb9] = "CPDR",
		[0xba] = "INDR",
		[0xbb] = "OTDR",
		[0xc1] = "MULUB A,B",
		[0xc3] = "MULUW HL,BC",
		[0xc9] = "MULUB A,C",
		[0xd1] = "MULUB A,D",
		[0xd9] = "MULUB A,E",
		[0xe1] = "MULUB A,H",
		[0xe9] = "MULUB A,L",
		[0xf3] = "MULUW HL,SP",
		[0xf9] = "MULUB A,A" },
	[0xee] = { n = "XOR n" },
	[0xef] = "RST 28H",
	[0xf0] = "RET P",
	[0xf1] = "POP AF",
	[0xf2] = { nn = { nn = "JP P,nn" } },
	[0xf3] = "DI",
	[0xf4] = { nn = { nn = "CALL P,nn" } },
	[0xf5] = "PUSH AF",
	[0xf6] = { n = "OR n" },
	[0xf7] = "RST 30H",
	[0xf8] = "RET M",
	[0xf9] = "LD SP,HL",
	[0xfa] = { nn = { nn = "JP M,nn" } },
	[0xfb] = "EI",
	[0xfc] = { nn = { nn = "CALL M,nn" } },
	[0xfd] = { 
		[0x09] = "ADD IY,BC",
		[0x19] = "ADD IY,DE",
		[0x21] = { nn = { nn = "LD IY,nn" } },
		[0x22] = { nn = { nn = "LD (nn),IY" } },
		[0x23] = "INC IY",
		[0x24] = "INC IYh",
		[0x25] = "DEC IYh",
		[0x26] = { n = "LD IYh,n" },
		[0x29] = "ADD IY,IY",
		[0x2a] = { nn = { nn = "LD IY,(nn)" } },
		[0x2b] = "DEC IY",
		[0x2c] = "INC IYl",
		[0x2d] = "DEC IYl",
		[0x2e] = { n = "LD IYl,n" },
		[0x34] = { o = "INC (IY+o)" },
		[0x35] = { o = "DEC (IY+o)" },
		[0x36] = { o = { n = "LD (IY+o),n" } },
		[0x39] = "ADD IY,SP",
		[0x44] = "LD B,IYh",
		[0x45] = "LD B,IYl",
		[0x46] = { o = "LD B,(IY+o)" },
		[0x4c] = "LD C,IYh",
		[0x4d] = "LD C,IYl",
		[0x4e] = { o = "LD C,(IY+o)" },
		[0x54] = "LD D,IYh",
		[0x55] = "LD D,IYl",
		[0x56] = { o = "LD D,(IY+o)" },
		[0x5c] = "LD E,IYh",
		[0x5d] = "LD E,IYl",
		[0x5e] = { o = "LD E,(IY+o)" },
		[0x64] = "LD IYh,h",
		[0x65] = "LD IYh,l",
		[0x66] = { o = "LD H,(IY+o)" },
		[0x6c] = "LD IYl,h",
		[0x6d] = "LD IYl,l",
		[0x6e] = { o = "LD L,(IY+o)" },
		[0x70] = { o = "LD (IY+o),B" },
		[0x71] = { o = "LD (IY+o),C" },
		[0x72] = { o = "LD (IY+o),D" },
		[0x73] = { o = "LD (IY+o),E" },
		[0x74] = { o = "LD (IY+o),H" },
		[0x75] = { o = "LD (IY+o),L" },
		[0x77] = { o = "LD (IY+o),A" },
		[0x7c] = "LD A,IYh",
		[0x7d] = "LD A,IYl",
		[0x7e] = { o = "LD A,(IY+o)" },
		[0x84] = "ADD A,IYh",
		[0x85] = "ADD A,IYl",
		[0x86] = { o = "ADD A,(IY+o)" },
		[0x8c] = "ADC A,IYh",
		[0x8d] = "ADC A,IYl",
		[0x8e] = { o = "ADC A,(IY+o)" },
		[0x94] = "SUB IYh",
		[0x95] = "SUB IYl",
		[0x96] = { o = "SUB (IY+o)" },
		[0x9c] = "SBC A,IYh",
		[0x9d] = "SBC A,IYl",
		[0x9e] = { o = "SBC A,(IY+o)" },
		[0xa4] = "AND IYh",
		[0xa5] = "AND IYl",
		[0xa6] = { o = "AND (IY+o)" },
		[0xac] = "XOR IYh",
		[0xad] = "XOR IYl",
		[0xae] = { o = "XOR (IY+o)" },
		[0xb4] = "OR IYh",
		[0xb5] = "OR IYl",
		[0xb6] = { o = "OR (IY+o)" },
		[0xbc] = "CP IYh",
		[0xbd] = "CP IYl",
		[0xbe] = { o = "CP (IY+o)" },
		[0xcb] = { o = { 
				[0x06] = "RLC (IY+o)",
				[0x0e] = "RRC (IY+o)",
				[0x16] = "RL (IY+o)",
				[0x1e] = "RR (IY+o)",
				[0x26] = "SLA (IY+o)",
				[0x2e] = "SRA (IY+o)",
				[0x3e] = "SRL (IY+o)",
				[0x46] = "BIT 0,(IY+o)",
				[0x4e] = "BIT 1,(IY+o)",
				[0x56] = "BIT 2,(IY+o)",
				[0x5e] = "BIT 3,(IY+o)",
				[0x66] = "BIT 4,(IY+o)",
				[0x6e] = "BIT 5,(IY+o)",
				[0x76] = "BIT 6,(IY+o)",
				[0x7e] = "BIT 7,(IY+o)",
				[0x86] = "RES 0,(IY+o)",
				[0x8e] = "RES 1,(IY+o)",
				[0x96] = "RES 2,(IY+o)",
				[0x9e] = "RES 3,(IY+o)",
				[0xa6] = "RES 4,(IY+o)",
				[0xae] = "RES 5,(IY+o)",
				[0xb6] = "RES 6,(IY+o)",
				[0xbe] = "RES 7,(IY+o)",
				[0xc6] = "SET 0,(IY+o)",
				[0xce] = "SET 1,(IY+o)",
				[0xd6] = "SET 2,(IY+o)",
				[0xde] = "SET 3,(IY+o)",
				[0xe6] = "SET 4,(IY+o)",
				[0xee] = "SET 5,(IY+o)",
				[0xf6] = "SET 6,(IY+o)",
				[0xfe] = "SET 7,(IY+o)" } },
		[0xe1] = "POP IY",
		[0xe3] = "EX (SP),IY",
		[0xe5] = "PUSH IY",
		[0xe9] = "JP (IY)",
		[0xf9] = "LD SP,IY" },
	[0xfe] = { n = "CP n" },
	[0xff] = "RST 38H" }