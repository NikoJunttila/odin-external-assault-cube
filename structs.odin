package external

Config :: struct {
	target_health:      i32,
	target_ammo:        i32,
	update_interval_ms: u32,
}

default_config :: proc() -> Config {
	return Config{target_health = 100, target_ammo = 20, update_interval_ms = 1000}
}
// POINT3D equivalent in Odin
Point3D :: struct {
	x: f32,
	y: f32,
	z: f32,
}

// ACPLAYER struct converted to Odin
ACPlayer :: struct {
	unknown1:                 [4]byte, // +0x0
	headPosition:             Point3D, // +0x4
	unknown2:                 [0x24]byte, // +0x10
	position:                 Point3D, // +0x34
	view:                     Point3D, // +0x40
	unknown3:                 [8]byte, // +0x58
	jumpFallSpeed:            i32, // +0x54
	noClip:                   f32, // +0x58
	unknown4:                 [0x14]byte, // +0x5C
	isImmobile:               i32, // +0x70
	unknown5:                 [0xE]byte, // +0x74
	state:                    i8, // +0x82
	unknown6:                 [0x75]byte, // +0x83
	hp:                       i32, // +0xF8
	armor:                    i32, // +0xFC
	unknown7:                 [0xC]byte, // +0x100
	dualPistolEnabled:        i8, // +0x10C
	unknown8:                 [0x7]byte, // +0x10D
	pistolReserveAmmos:       i32, // +0x114
	carabineReserveAmmos:     i32, // +0x118
	shotgunReserveAmmos:      i32, // +0x11C
	smgReserveAmmos:          i32, // +0x120
	sniperRifleReserveAmmos:  i32, // +0x124
	assaultRifleReserveAmmos: i32, // +0x128
	unknown9:                 [0x8]byte, // +0x12C
	doublePistolReserveAmmos: i32, // +0x134
	unknown10:                [0x4]byte, // +0x138
	pistolLoadedAmmos:        i32, // +0x13C
	carabineLoadedAmmos:      i32, // +0x140
	shotgunLoadedAmmos:       i32, // +0x144
	smgLoadedAmmos:           i32, // +0x148
	sniperRifleLoadedAmmos:   i32, // +0x14C
	assaultRifleLoadedAmmos:  i32, // +0x150
	unknown11:                [0x4]byte, // +0x154
	grenades:                 i32, // +0x158
	doublePistolLoadedAmmos:  i32, // +0x15C
	knifeSlashDelay:          i32, // +0x160
	pistolShootDelay:         i32, // +0x164
	carabineShootDelay:       i32, // +0x168
	shotgunShootDelay:        i32, // +0x16C
	smgShootDelay:            i32, // +0x170
	sniperRifleShootDelay:    i32, // +0x174
	assaultRifleShootDelay:   i32, // +0x178
	unknown12:                [0x8]byte, // +0x17C
	doublePistolShootDelay:   i32, // +0x184
	unknown13:                [0x7C]byte, // +0x188
	numberOfDeaths:           i32, // +0x204
	unknown14:                [0x1D]byte, // +0x208
	nickname:                 [16]byte, // +0x225 (CHAR converted to byte array)
	unknown15:                [0xF7]byte, // +0x235
	team:                     i8, // +0x32C
}