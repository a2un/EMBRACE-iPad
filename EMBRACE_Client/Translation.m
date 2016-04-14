//
//  Translation.m
//  EMBRACE
//
//  Created by Jonatan Lemos Zuluaga (Student) on 5/13/14.
//  Copyright (c) 2014 Andreea Danielescu. All rights reserved.
//

#import "Translation.h"

@implementation Translation

+(NSDictionary *) translationWords {
    static NSDictionary * inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = @{
                 @"award" : @"premio",
                 @"barn" : @"establo",
                 @"bucket" : @"cubeta",
                 @"cannot" : @[@"no puedo", @"no puedes"],
                 @"carried" : @"llevó",
                 @"cart" : @"carretilla",
                 @"chicken" : @"pollo",
                 @"chicken's" : @"del pollo",
                 @"brushed" : @[@"cepillar", @"cepilló"],
                 @"contest" : @"concurso",
                 @"corral" : @"corral",
                 @"counted" : @"contó",
                 @"farm" : @"granja",
                 @"fattest" : @"el más gordo",
                 @"flew" : @"voló",
                 @"gate" : @"reja",
                 @"hay" : @"paja",
                 @"hayloft" : @"pajar",
                 @"healthy" : @"sano",
                 @"hopped" : @"brincó",
                 @"judge" : @"juez",
                 @"jumped" : @"brincó",
                 @"locked" : @"encerrado",
                 @"manuel" : @"manuel",
                 @"manuel's" : @"de manuel",
                 @"nest" : @"nido",
                 @"owl" : @"búho",
                 @"prize" : @"premio",
                 @"pumpkin" : @"calabaza",
                 @"pumpkins" : @"calabazas",
                 @"purr" : @"ronronear",
                 @"shiny" : @"brillante",
                 @"tasted" : @"probó",
                 @"trophy" : @"trofeo",
                 @"walked" : @"caminó",
                 @"weeds" : @"malezas",
                 @"wise" : @"sabio",
                 
                 @"around": @"alrededor",
                 @"arteries": @"arterias",
                 @"atoms": @"átomos",
                 @"atrium": @"atrio",
                 @"beat": @"latir",
                 @"blood": @"sangre",
                 @"breathe": @"respirar",
                 @"carbon dioxide": @"dióxido de carbono",
                 @"chest": @"pecho",
                 @"cigarette": @"cigarrillo",
                 @"cilia": @"cilias",
                 @"dirt": @"mugre",
                 @"dust": @"polvo",
                 @"energy": @"energía",
                 @"heart": @"corazón",
                 @"lungs": @"pulmones",
                 @"molecules": @"moléculas",
                 @"muscles": @"músculos",
                 @"oxygen": @"oxígeno",
                 @"pumps": @"bombear",
                 @"rushes": @"fluye",
                 @"squeeze": @"apretar",
                 @"stiff": @"rígido",
                 @"toward": @"hacia",
                 @"trapped": @"atrapada",
                 @"tubes": @"tubos",
                 @"valve": @"válvula",
                 @"veins": @"venas",
                 @"ventricle": @"ventrículo",
                 
                 @"hook": @"gancho",
                 @"lawyer": @[@"abogado", @"abogada"],
                 @"pets": @"mascotas",
                 @"mystery": @"misterio",
                 @"solve": @"resolver",
                 @"solved": @"resuelto",
                 @"highchair": @"silla alta",
                 @"sniffed": @[@"olfatear", @"olfateó"],
                 @"thief": @"ladrón",
                 @"stealing": @"robar",
                 @"rattle": @"sonaja",
                 @"silver": @[@"plateado", @"plateada"],
                 @"comfort": @"calmar",
                 @"rattled": @"angustiado",
                 @"shiny": @[@"brillante", @"brillantes"],
                 @"breakfast": @"desayuno",
                 @"comfort": @"calmar",
                 @"drove": @[@"manejar", @"manejó"],
                 @"hero": @"héroe",
                 @"kitchen": @"cocina",
                 @"pancakes": @"panqueques",
                 @"policeman": @"policía",
                 @"suddenly": @"de repente",
                 @"toward": @"hacia",
                 
                 @"spin": @"gire",
                 
                 @"banana": @"plátano",
                 @"coco": @"coco",
                 @"empty": @"vacío",
                 @"handle": @"manija",
                 @"jumps": @"salta",
                 @"lifts": @"levanta",
                 @"lisa": @"lisa",
                 @"monkey": @"chango",
                 @"naughty": @"travieso",
                 @"throws": @"tira",
                 @"trough": @"bebedero",
                 @"zebra's": @"cebra",
                 
                 @"algonquian" : @"algonquian",
                 @"algonquians" : @"algonquians",
                 @"arrow" : @"flecha",
                 @"arrows" : @"flechas",
                 @"bark" : @"corteza",
                 @"bows" : @"arcos",
                 @"branches" : @"ramas",
                 @"buffalo" : @"búfalo",
                 @"canoes" : @"canoas",
                 @"carving" : @"tallar",
                 @"cedar" : @"cedro",
                 @"ceremonies" : @"ceremonias",
                 @"chickee" : @"chickee",
                 @"chickees" : @"chickees",
                 @"comfortable" : @"cómodos",
                 @"community" : @"comunidad",
                 @"entryway" : @"entrada",
                 @"everglades" : @"marismas",
                 @"flexible" : @"flexible",
                 @"frame" : @"estructura",
                 @"haida" : @"haida",
                 @"haidas" : @"haidas",
                 @"hogan" : @"hogan",
                 @"hunted" : @"cazar",
                 @"igloo" : @"iglú",
                 @"igloos" : @"iglús",
                 @"inuit" : @"inuit",
                 
                 @"modern" : @[@"modernas", @"moderno"],
                 
                 @"mosquitos" : @"mosquitos",
                 @"narrow" : @"angosto",
                 @"navajo" : @"navajo",
                 @"navajos" : @"navajos",
                 @"octagon" : @"octágono",
                 @"opposite" : @"opuesto",
                 @"pacific" : @"pacífico",
                 @"plagued" : @"plagados",
                 @"plank" : @"tablón",
                 @"planks" : @"tablónes",
                 
                 @"protect" : @[@"proteger", @"protegen"],
                 
                 @"protected" : @"protegía",
                 @"seminole" : @"seminole",
                 @"seminoles" : @"seminoles",
                 @"sioux" : @"sioux",
                 @"slanted" : @"inclinado",
                 @"sled" : @"trineo",
                 @"sophisticated" : @"sofisticado",
                 @"stilts" : @"estacas",
                 @"swamps" : @"ciénagas",
                 @"teepee" : @"tipi",
                 @"teepees" : @"tipis",
                 @"totem poles" : @"tótem",
                 @"upright" : @"verticales",
                 @"wigwam" : @"wigwam",
                 @"wigwams" : @"wigwams",
                 
                 @"adopted" : @"adoptado",
                 @"advice" : @"consejo",
                 @"appeared" : @"aparecido",
                 @"beautiful" : @"hermoso",
                 @"board-game" : @"juego de mesa",
                 @"bottle" : @"botella",
                 @"circles" : @"círculos",
                 @"couldn't" : @"no poder",
                 @"decided" : @"decidir",
                 @"exactly" : @"exactamente",
                 @"excitement" : @"emoción",
                 @"floating" : @"flotando",
                 @"friends" : @"amigos",
                 @"giggle" : @"risilla",
                 @"granted" : @[@"concedió",@"concederán"],
                 @"instead" : @"en vez de",
                 @"magically" : @"magicamente",
                 @"noticed" : @"notar",
                 @"overlooked" : @[@"tener vista",@"tenía vista"],
                 @"rattle" : @"sonaja",
                 @"realized" : @"darse cuenta",
                 @"relieved" : @"aliviado",
                 @"sight" : @"vista",
                 @"silly" : @"tonto",
                 @"somebody" : @"alguien",
                 @"something" : @"algo",
                 @"special" : @"especial",
                 @"stared" : @"mirar fijamente",
                 @"stroll" : @"paseo",
                 @"thought" : @[@"pensar",@"pensó"],
                 @"tossed" : @[@"tirar",@"tiró"],
                 @"tumbled" : @[@"rodar",@"rodó"],
                 @"understood" : @"entender",
                 @"wisdom" : @"sabiduría",
                 @"wishes" : @"deseos",
                 @"within" : @"dentro",
                 @"wrapped" : @[@"envuelto",@"envuelta"]
                 
        };
    });
    return inst;
}

+(NSDictionary *) translationWordsSpanish {
    static NSDictionary * inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = @{
                 @"premio" : @"award",
                 @"establo" : @"barn",
                 @"cubeta" : @"bucket",
                 @"no puedes" : @"cannot",
                 @"no puedo" : @"cannot",
                 @"llevó" : @"carried",
                 @"carretilla" : @"cart",
                 @"pollo" : @"chicken",
                 @"del pollo" : @"chicken's",
                 @"cepillar" : @"brushed",
                 @"cepilló" : @"brushed",
                 @"concurso" : @"contest",
                 @"corral" : @"corral",
                 @"contó" : @"counted",
                 @"granja" : @"farm",
                 @"el más gordo" : @"fattest",
                 @"voló" : @"flew",
                 @"reja" : @"gate",
                 @"paja" : @"hay",
                 @"pajar" : @"hayloft",
                 @"sano" : @"healthy",
                 @"brincó" : @"hopped",
                 @"juez" : @"judge",
                 @"brincó" : @"jumped",
                 @"encerrado" : @"locked",
                 @"manuel" : @"manuel",
                 @"de manuel" : @"manuel's",
                 @"nido" : @"nest",
                 @"búho" : @"owl",
                 @"premio" : @"prize",
                 @"calabaza" : @"pumpkin",
                 @"calabazas" : @"pumpkins",
                 @"ronronear" : @"purr",
                 @"brillante" : @"shiny",
                 @"probó" : @"tasted",
                 @"trofeo" : @"trophy",
                 @"caminó" : @"walked",
                 @"malezas" : @"weeds",
                 @"sabio" : @"wise",
                 
                 @"alrededor": @"around",
                 @"arterias": @"arteries",
                 @"átomos": @"atoms",
                 @"atrio": @"atrium",
                 @"latir": @"beat",
                 @"sangre": @"blood",
                 @"respirar": @"breathe",
                 @"dióxido de carbono": @"carbon dioxide",
                 @"pecho": @"chest",
                 @"cigarrillo": @"cigarette",
                 @"cilias": @"cilia",
                 @"mugre": @"dirt",
                 @"polvo": @"dust",
                 @"energía": @"energy",
                 @"corazón": @"heart",
                 @"pulmones": @"lungs",
                 @"moléculas": @"molecules",
                 @"músculos": @"muscles",
                 @"oxígeno": @"oxygen",
                 @"bombear": @"pumps",
                 @"fluye": @"rushes",
                 @"apretar": @"squeeze",
                 @"rígido": @"stiff",
                 @"hacia": @"toward",
                 @"atrapada": @"trapped",
                 @"tubos": @"tubes",
                 @"válvula": @"valve",
                 @"venas": @"veins",
                 @"ventrículo": @"ventricle",
                 
                 @"gancho": @"hook",
                 @"abogada": @"lawyer",
                 @"abogado": @"lawyer",
                 @"mascotas": @"pets",
                 @"misterio": @"mystery",
                 @"resolver": @"solve",
                 @"resuelto": @"solved",
                 @"silla alta": @"highchair",
                 @"olfatear": @"sniffed",
                 @"olfateó": @"sniffed",
                 @"ladrón": @"thief",
                 @"robar": @"stealing",
                 @"sonaja": @"rattle",
                 @"plateada": @"silver",
                 @"plateado": @"silver",
                 @"calmar": @"comfort",
                 @"angustiado": @"rattled",
                 @"brillante": @"shiny",
                 @"brillantes": @"shiny",
                 @"desayuno": @"breakfast",
                 @"calmar": @"comfort",
                 @"manejar": @"drove",
                 @"manejó": @"drove",
                 @"héroe": @"hero",
                 @"cocina": @"kitchen",
                 @"panqueques": @"pancakes",
                 @"policía": @"policeman",
                 @"de repente": @"suddenly",
                 @"hacia": @"toward",
                 
                 @"gire": @"spin",
                 
                 @"plátano": @"banana",
                 @"coco": @"coco",
                 @"vacío": @"empty",
                 @"manija": @"handle",
                 @"salta": @"jumps",
                 @"levanta": @"lifts",
                 @"lisa": @"lisa",
                 @"chango": @"monkey",
                 @"travieso": @"naughty",
                 @"tira": @"throws",
                 @"bebedero": @"trough",
                 @"cebra": @"zebra's",
                 
                 @"algonquian" : @"algonquian",
                 @"algonquians" : @"algonquians",
                 @"flecha": @"arrow" ,
                 @"flechas": @"arrows",
                 @"corteza": @"bark",
                 @"arcos": @"bows",
                 @"ramas": @"branches",
                 @"búfalo": @"buffalo",
                 @"canoas": @"canoes",
                 @"tallar": @"carving" ,
                 @"cedro": @"cedar" ,
                 @"ceremonias": @"ceremonies",
                 @"chickee": @"chickee" ,
                 @"chickees" : @"chickees",
                 @"cómodos":  @"comfortable",
                 @"comunidad": @"community" ,
                 @"entrada": @"entryway" ,
                 @"marismas": @"everglades",
                 @"flexible" : @"flexible",
                 @"estructura": @"frame" ,
                 @"haida" : @"haida",
                 @"haidas" : @"haidas",
                 @"hogan" : @"hogan",
                 @"cazar": @"hunted" ,
                 @"iglú": @"igloo" ,
                 @"iglús": @"igloos" ,
                 @"inuit" : @"inuit",
                 @"modernas": @"modern",
                 @"moderno": @"modern",
                 @"mosquitos" : @"mosquitos",
                 @"angosto": @"narrow" ,
                 @"navajo" : @"navajo",
                 @"navajos" : @"navajos",
                 @"octágono": @"octagon" ,
                 @"opuesto": @"opposite" ,
                 @"pacífico": @"pacific" ,
                 @"plagados": @"plagued" ,
                 @"tablón": @"plank" ,
                 @"tablónes": @"planks" ,
                 @"proteger": @"protect",
                 @"protegen": @"protect" ,
                 @"protegía": @"protected" ,
                 @"seminole" : @"seminole",
                 @"seminoles" : @"seminoles",
                 @"sioux" : @"sioux",
                 @"inclinado": @"slanted" ,
                 @"trineo": @"sled" ,
                 @"sofisticado": @"sophisticated" ,
                 @"estacas": @"stilts" ,
                 @"ciénagas": @"swamps" ,
                 @"tipi": @"teepee" ,
                 @"tipis": @"teepees",
                 @"tótem": @"totem poles",
                 @"verticales": @"upright",
                 @"wigwam" : @"wigwam",
                 @"wigwams" : @"wigwams",
                 
                 @"adoptado": @"adopted",
                 @"consejo": @"advice",
                 @"aparecido": @"appeared",
                 @"hermoso": @"beautiful",
                 @"juego de mesa": @"board-game",
                 @"botella": @"bottle",
                 @"círculos": @"circles",
                 @"no poder": @"couldn't",
                 @"decidir": @"decided",
                 @"exactamente": @"exactly",
                 @"emoción": @"excitement",
                 @"flotando": @"floating",
                 @"amigos": @"friends",
                 @"risilla": @"giggle",
                 @"concedió": @"granted",
                 @"concederán": @"granted",
                 @"en vez de": @"instead",
                 @"magicamente": @"magically",
                 @"notar":  @"noticed",
                 @"tener vista": @"overlooked",
                 @"tenía vista": @"overlooked",
                 @"sonaja": @"rattle",
                 @"darse cuenta": @"realized",
                 @"aliviado": @"relieved",
                 @"vista": @"sight",
                 @"tonto": @"silly",
                 @"alguien": @"somebody",
                 @"algo": @"something",
                 @"especial": @"special",
                 @"mirar fijamente": @"stared",
                 @"paseo": @"stroll",
                 @"pensar": @"thought",
                 @"pensó": @"thought",
                 @"tirar": @"tossed",
                 @"tiró": @"tossed",
                 @"rodar": @"tumbled",
                 @"rodó": @"tumbled",
                 @"entender": @"understood",
                 @"sabiduría": @"wisdom",
                 @"deseos": @"wishes",
                 @"dentro": @"within",
                 @"envuelto": @"wrapped",
                 @"envuelta": @"wrapped"
                 
                 };
    });
    return inst;
}

+(NSDictionary *) translationImages {
    static NSDictionary * inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = @{
                 @"award" : @"award",
                 @"barn": @"barn",
                 @"bucket": @"bucket",
                 @"cart": @"cart",
                 @"chicken" : @"chicken",
                 @"chicken's" : @"chicken",
                 @"corral": @"corral",
                 @"farm": @"farm",
                 @"farmer": @"farmer",
                 @"gate": @"pen2",
                 @"hay": @"hay",
                 @"hayloft": @"hayloft",
                 @"judge": @"judge",
                 @"manuel" : @"farmer",
                 @"manuel's" : @"farmer",
                 @"nest": @"chickenNest",
                 @"owl": @"owl",
                 @"pen": @"pen4",
                 @"pumpkin": @"pumpkin",
                 @"pumpkins" : @"pumpkinPatch",
                 @"trophy": @"award",
                 @"weeds": @"weeds",
                 
                 @"around": @"around",
                 @"arteries": @"arteries",
                 @"atoms": @"atoms",
                 @"atrium": @[@"atrium_1",@"atrium_2"],
                 @"beat": @"beat",
                 @"blood": @"bloodcell_1",
                 @"breathe": @"breathe",
                 @"carbon dioxide": @[@"CO2_1",@"CO2_2",@"CO2_3"],
                 @"chest": @"chest",
                 @"cigarette": @"cigarette",
                 @"cilia": @[@"cilia1",@"cilia2"],
                 @"dirt": @[@"dirt_1",@"dirt_3",@"dirt_4",@"dirt_5",@"dirt_6",@"dirt_7"],
                 @"dust": @"dust",
                 @"energy": @"energy",
                 @"heart": @"heart",
                 @"lungs": @"lungs",
                 @"molecules": @[@"CO2_1",@"CO2_2",@"CO2_3",@"O2_1"],
                 @"muscles": @"muscles",
                 @"oxygen": @"O2_1",
                 @"pumps": @"pumps",
                 @"rushes": @"rushes",
                 @"squeeze": @"squeeze",
                 @"stiff": @"stiff",
                 @"toward": @"toward",
                 @"trapped": @"trapped",
                 @"tubes": @"tubes",
                 @"valve": @[@"handle",@"handle_close",@"handle_1",@"gray_handle"],
                 @"veins": @"veins",
                 @"ventricle": @[@"ventricle_1", @"ventricle_2"],
                 
                 @"baby": @"baby",
                 @"car": @"car",
                 @"highchair": @"highchairb",
                 @"hook": @"hook",
                 @"keys": @"keys2",
                 @"kitchen": @"kitchen",
                 @"lola": @"rabbit",
                 @"martin": @"man",
                 @"paco": @"dog",
                 @"pets": @[@"dog", @"rabbit"],
                 @"rattle": @"rattle",
                 @"rosa": @"woman",
                 
                 @"banana": @"banana",
                 @"coco": @"monkey",
                 @"empty": @"empty",
                 @"handle": @"handle",
                 @"jumps": @"salta",
                 @"lifts": @"lifts",
                 @"lisa": @"lisa",
                 @"monkey": @"monkey",
                 @"naughty": @"naughty",
                 @"throws": @"tira",
                 @"trough": @"trough",
                 @"zebra's": @"zebra",
                 
                 @"algonquian" : @[@"man_ch4", @"woman_ch4"],
                 @"algonquians" : @[@"man_ch4", @"woman_ch4"],
                 @"arrow" : @"arrow",
                 @"arrows" : @"arrows",
                 @"bark" : @[@"bark", @"bark2"],
                 @"bows" : @"bows",
                 @"branches" : @"branch",
                 @"buffalo" : @[@"buffalo1", @"buffalo2", @"buffalo3"],
                 @"canoes" : @"boat",
                 @"carving" : @"carving",
                 @"cedar" : @"cedar",
                 @"ceremonies" : @"ceremonies",
                 @"chickee" : @"chickee",
                 @"chickees" : @"chickee",
                 @"comfortable" : @"comfortable",
                 @"community" : @"community",
                 @"entryway" : @"entryway",
                 @"everglades" : @"everglades",
                 @"flexible" : @"flexible",
                 @"frame" : @"frame",
                 @"haida" : @"haida",
                 @"haidas" : @"haida",
                 @"hogan" : @"hogan",
                 @"hunted" : @"hunted",
                 @"igloo" : @"igloo",
                 @"igloos" : @"igloo",
                 @"inuit" : @"inuit",
                 @"modern" : @"modern",
                 @"mosquitos" : @[@"mosquito1", @"mosquito2", @"mosquito3"],
                 @"narrow" : @"narrow",
                 @"navajo" : @[@"man1", @"man2", @"man3", @"woman1", @"woman2", @"woman3"],
                 @"navajos" : @[@"man1", @"man2", @"man3", @"woman1", @"woman2", @"woman3"],
                 @"octagon" : @"octagon",
                 @"opposite" : @"opposite",
                 @"pacific" : @"pacific",
                 @"plagued" : @"plagued",
                 @"plank" : @[@"plank", @"plank_pile"],
                 @"planks" : @[@"plank", @"plank_pile"],
                 @"protect" : @"protect",
                 @"protected" : @"protected",
                 @"seminole" : @"seminole_dad",
                 @"seminoles" : @"seminole_dad",
                 @"sioux" : @[@"sioux", @"man3_ch3", @"standing_sioux"],
                 @"slanted" : @"slanted",
                 @"sled" : @"travois",
                 @"sophisticated" : @"sophisticated",
                 @"stilts" : @"chickee",
                 @"swamps" : @"swamps",
                 @"teepee" : @"teepee",
                 @"teepees" : @"teepee",
                 @"totem poles" : @"totem poles",
                 @"upright" : @"upright",
                 @"wigwam" : @"wigwam",
                 @"wigwams" : @"wigwam",
                 
                 @"adopted" : @"adopted",
                 @"advice" : @"advice",
                 @"appeared" : @"appeared",
                 @"beautiful" : @"beautiful",
                 @"board-game" : @[@"boardgame", @"boardgame_open"],
                 @"bottle" : @"bottle",
                 @"circles" : @"circles",
                 @"couldn't" : @"couldn't",
                 @"decided" : @"decided",
                 @"exactly" : @"exactly",
                 @"excitement" : @"excitement",
                 @"floating" : @"floating",
                 @"friends" : @"friends",
                 @"giggle" : @"giggle",
                 @"granted" : @"granted",
                 @"instead" : @"instead",
                 @"magically" : @"magically",
                 @"noticed" : @"noticed",
                 @"overlooked" : @"overlooked",
                 @"rattle" : @"rattle",
                 @"realized" : @"realized",
                 @"relieved" : @"relieved",
                 @"sight" : @"sight",
                 @"silly" : @"silly",
                 @"somebody" : @"somebody",
                 @"something" : @"something",
                 @"special" : @"special",
                 @"stared" : @"stared",
                 @"stroll" : @"stroll",
                 @"thought" : @"thought",
                 @"tossed" : @"tossed",
                 @"tumbled" : @"tumbled",
                 @"understood" : @"understood",
                 @"wisdom" : @"wisdom",
                 @"wishes" : @"wishes",
                 @"within" : @"within",
                 @"wrapped" : @"wrapped"
                 
                 
                 };
    });
    return inst;
}

@end
