module adc (
    input wire clk,              // System clock
    input wire rst_n,            // Active low reset
    input wire [15:0] adc_data,  // ADC input data (16-bit Q1.15 format)
    input wire adc_clk,          // ADC sampling clock
    output reg [15:0] data_out,  // Processed ADC data (16-bit Q1.15 format)
    output reg data_valid        // Data valid signal
);

// Parameters for sampling
parameter BUFFER_DEPTH = 2048;

// Internal signals
reg [15:0] sample_buffer [0:BUFFER_DEPTH-1];
reg [$clog2(BUFFER_DEPTH)-1:0] write_ptr;
integer i;

// 汉宁窗系数数组 (2048点)
reg [15:0] hanning_window [0:BUFFER_DEPTH-1];

// 初始化汉宁窗系数
initial begin
    // 索引    0-   7
    hanning_window[   0] = 16'h0000; hanning_window[   1] = 16'h0000; hanning_window[   2] = 16'h0000; hanning_window[   3] = 16'h0001; hanning_window[   4] = 16'h0001; hanning_window[   5] = 16'h0002; hanning_window[   6] = 16'h0003; hanning_window[   7] = 16'h0004; 
    // 索引    8-  15
    hanning_window[   8] = 16'h0005; hanning_window[   9] = 16'h0006; hanning_window[  10] = 16'h0008; hanning_window[  11] = 16'h0009; hanning_window[  12] = 16'h000B; hanning_window[  13] = 16'h000D; hanning_window[  14] = 16'h000F; hanning_window[  15] = 16'h0011; 
    // 索引   16-  23
    hanning_window[  16] = 16'h0014; hanning_window[  17] = 16'h0016; hanning_window[  18] = 16'h0019; hanning_window[  19] = 16'h001C; hanning_window[  20] = 16'h001F; hanning_window[  21] = 16'h0022; hanning_window[  22] = 16'h0025; hanning_window[  23] = 16'h0029; 
    // 索引   24-  31
    hanning_window[  24] = 16'h002C; hanning_window[  25] = 16'h0030; hanning_window[  26] = 16'h0034; hanning_window[  27] = 16'h0038; hanning_window[  28] = 16'h003C; hanning_window[  29] = 16'h0041; hanning_window[  30] = 16'h0045; hanning_window[  31] = 16'h004A; 
    // 索引   32-  39
    hanning_window[  32] = 16'h004F; hanning_window[  33] = 16'h0054; hanning_window[  34] = 16'h0059; hanning_window[  35] = 16'h005E; hanning_window[  36] = 16'h0064; hanning_window[  37] = 16'h006A; hanning_window[  38] = 16'h006F; hanning_window[  39] = 16'h0075; 
    // 索引   40-  47
    hanning_window[  40] = 16'h007B; hanning_window[  41] = 16'h0082; hanning_window[  42] = 16'h0088; hanning_window[  43] = 16'h008F; hanning_window[  44] = 16'h0095; hanning_window[  45] = 16'h009C; hanning_window[  46] = 16'h00A3; hanning_window[  47] = 16'h00AA; 
    // 索引   48-  55
    hanning_window[  48] = 16'h00B2; hanning_window[  49] = 16'h00B9; hanning_window[  50] = 16'h00C1; hanning_window[  51] = 16'h00C8; hanning_window[  52] = 16'h00D0; hanning_window[  53] = 16'h00D8; hanning_window[  54] = 16'h00E1; hanning_window[  55] = 16'h00E9; 
    // 索引   56-  63
    hanning_window[  56] = 16'h00F1; hanning_window[  57] = 16'h00FA; hanning_window[  58] = 16'h0103; hanning_window[  59] = 16'h010C; hanning_window[  60] = 16'h0115; hanning_window[  61] = 16'h011E; hanning_window[  62] = 16'h0128; hanning_window[  63] = 16'h0131; 
    // 索引   64-  71
    hanning_window[  64] = 16'h013B; hanning_window[  65] = 16'h0145; hanning_window[  66] = 16'h014F; hanning_window[  67] = 16'h0159; hanning_window[  68] = 16'h0164; hanning_window[  69] = 16'h016E; hanning_window[  70] = 16'h0179; hanning_window[  71] = 16'h0184; 
    // 索引   72-  79
    hanning_window[  72] = 16'h018E; hanning_window[  73] = 16'h019A; hanning_window[  74] = 16'h01A5; hanning_window[  75] = 16'h01B0; hanning_window[  76] = 16'h01BC; hanning_window[  77] = 16'h01C7; hanning_window[  78] = 16'h01D3; hanning_window[  79] = 16'h01DF; 
    // 索引   80-  87
    hanning_window[  80] = 16'h01EB; hanning_window[  81] = 16'h01F8; hanning_window[  82] = 16'h0204; hanning_window[  83] = 16'h0211; hanning_window[  84] = 16'h021E; hanning_window[  85] = 16'h022A; hanning_window[  86] = 16'h0238; hanning_window[  87] = 16'h0245; 
    // 索引   88-  95
    hanning_window[  88] = 16'h0252; hanning_window[  89] = 16'h0260; hanning_window[  90] = 16'h026D; hanning_window[  91] = 16'h027B; hanning_window[  92] = 16'h0289; hanning_window[  93] = 16'h0297; hanning_window[  94] = 16'h02A5; hanning_window[  95] = 16'h02B4; 
    // 索引   96- 103
    hanning_window[  96] = 16'h02C2; hanning_window[  97] = 16'h02D1; hanning_window[  98] = 16'h02E0; hanning_window[  99] = 16'h02EF; hanning_window[ 100] = 16'h02FE; hanning_window[ 101] = 16'h030D; hanning_window[ 102] = 16'h031C; hanning_window[ 103] = 16'h032C; 
    // 索引  104- 111
    hanning_window[ 104] = 16'h033C; hanning_window[ 105] = 16'h034C; hanning_window[ 106] = 16'h035C; hanning_window[ 107] = 16'h036C; hanning_window[ 108] = 16'h037C; hanning_window[ 109] = 16'h038C; hanning_window[ 110] = 16'h039D; hanning_window[ 111] = 16'h03AE; 
    // 索引  112- 119
    hanning_window[ 112] = 16'h03BF; hanning_window[ 113] = 16'h03D0; hanning_window[ 114] = 16'h03E1; hanning_window[ 115] = 16'h03F2; hanning_window[ 116] = 16'h0404; hanning_window[ 117] = 16'h0415; hanning_window[ 118] = 16'h0427; hanning_window[ 119] = 16'h0439; 
    // 索引  120- 127
    hanning_window[ 120] = 16'h044B; hanning_window[ 121] = 16'h045D; hanning_window[ 122] = 16'h046F; hanning_window[ 123] = 16'h0482; hanning_window[ 124] = 16'h0494; hanning_window[ 125] = 16'h04A7; hanning_window[ 126] = 16'h04BA; hanning_window[ 127] = 16'h04CD; 
    // 索引  128- 135
    hanning_window[ 128] = 16'h04E0; hanning_window[ 129] = 16'h04F4; hanning_window[ 130] = 16'h0507; hanning_window[ 131] = 16'h051B; hanning_window[ 132] = 16'h052F; hanning_window[ 133] = 16'h0542; hanning_window[ 134] = 16'h0556; hanning_window[ 135] = 16'h056B; 
    // 索引  136- 143
    hanning_window[ 136] = 16'h057F; hanning_window[ 137] = 16'h0593; hanning_window[ 138] = 16'h05A8; hanning_window[ 139] = 16'h05BD; hanning_window[ 140] = 16'h05D2; hanning_window[ 141] = 16'h05E7; hanning_window[ 142] = 16'h05FC; hanning_window[ 143] = 16'h0611; 
    // 索引  144- 151
    hanning_window[ 144] = 16'h0627; hanning_window[ 145] = 16'h063C; hanning_window[ 146] = 16'h0652; hanning_window[ 147] = 16'h0668; hanning_window[ 148] = 16'h067E; hanning_window[ 149] = 16'h0694; hanning_window[ 150] = 16'h06AA; hanning_window[ 151] = 16'h06C1; 
    // 索引  152- 159
    hanning_window[ 152] = 16'h06D7; hanning_window[ 153] = 16'h06EE; hanning_window[ 154] = 16'h0705; hanning_window[ 155] = 16'h071C; hanning_window[ 156] = 16'h0733; hanning_window[ 157] = 16'h074A; hanning_window[ 158] = 16'h0761; hanning_window[ 159] = 16'h0779; 
    // 索引  160- 167
    hanning_window[ 160] = 16'h0790; hanning_window[ 161] = 16'h07A8; hanning_window[ 162] = 16'h07C0; hanning_window[ 163] = 16'h07D8; hanning_window[ 164] = 16'h07F0; hanning_window[ 165] = 16'h0809; hanning_window[ 166] = 16'h0821; hanning_window[ 167] = 16'h083A; 
    // 索引  168- 175
    hanning_window[ 168] = 16'h0853; hanning_window[ 169] = 16'h086B; hanning_window[ 170] = 16'h0884; hanning_window[ 171] = 16'h089E; hanning_window[ 172] = 16'h08B7; hanning_window[ 173] = 16'h08D0; hanning_window[ 174] = 16'h08EA; hanning_window[ 175] = 16'h0903; 
    // 索引  176- 183
    hanning_window[ 176] = 16'h091D; hanning_window[ 177] = 16'h0937; hanning_window[ 178] = 16'h0951; hanning_window[ 179] = 16'h096B; hanning_window[ 180] = 16'h0986; hanning_window[ 181] = 16'h09A0; hanning_window[ 182] = 16'h09BB; hanning_window[ 183] = 16'h09D5; 
    // 索引  184- 191
    hanning_window[ 184] = 16'h09F0; hanning_window[ 185] = 16'h0A0B; hanning_window[ 186] = 16'h0A26; hanning_window[ 187] = 16'h0A42; hanning_window[ 188] = 16'h0A5D; hanning_window[ 189] = 16'h0A79; hanning_window[ 190] = 16'h0A94; hanning_window[ 191] = 16'h0AB0; 
    // 索引  192- 199
    hanning_window[ 192] = 16'h0ACC; hanning_window[ 193] = 16'h0AE8; hanning_window[ 194] = 16'h0B04; hanning_window[ 195] = 16'h0B20; hanning_window[ 196] = 16'h0B3D; hanning_window[ 197] = 16'h0B59; hanning_window[ 198] = 16'h0B76; hanning_window[ 199] = 16'h0B93; 
    // 索引  200- 207
    hanning_window[ 200] = 16'h0BB0; hanning_window[ 201] = 16'h0BCD; hanning_window[ 202] = 16'h0BEA; hanning_window[ 203] = 16'h0C07; hanning_window[ 204] = 16'h0C24; hanning_window[ 205] = 16'h0C42; hanning_window[ 206] = 16'h0C60; hanning_window[ 207] = 16'h0C7D; 
    // 索引  208- 215
    hanning_window[ 208] = 16'h0C9B; hanning_window[ 209] = 16'h0CB9; hanning_window[ 210] = 16'h0CD7; hanning_window[ 211] = 16'h0CF6; hanning_window[ 212] = 16'h0D14; hanning_window[ 213] = 16'h0D33; hanning_window[ 214] = 16'h0D51; hanning_window[ 215] = 16'h0D70; 
    // 索引  216- 223
    hanning_window[ 216] = 16'h0D8F; hanning_window[ 217] = 16'h0DAE; hanning_window[ 218] = 16'h0DCD; hanning_window[ 219] = 16'h0DEC; hanning_window[ 220] = 16'h0E0C; hanning_window[ 221] = 16'h0E2B; hanning_window[ 222] = 16'h0E4B; hanning_window[ 223] = 16'h0E6B; 
    // 索引  224- 231
    hanning_window[ 224] = 16'h0E8A; hanning_window[ 225] = 16'h0EAA; hanning_window[ 226] = 16'h0ECB; hanning_window[ 227] = 16'h0EEB; hanning_window[ 228] = 16'h0F0B; hanning_window[ 229] = 16'h0F2C; hanning_window[ 230] = 16'h0F4C; hanning_window[ 231] = 16'h0F6D; 
    // 索引  232- 239
    hanning_window[ 232] = 16'h0F8E; hanning_window[ 233] = 16'h0FAF; hanning_window[ 234] = 16'h0FD0; hanning_window[ 235] = 16'h0FF1; hanning_window[ 236] = 16'h1012; hanning_window[ 237] = 16'h1033; hanning_window[ 238] = 16'h1055; hanning_window[ 239] = 16'h1076; 
    // 索引  240- 247
    hanning_window[ 240] = 16'h1098; hanning_window[ 241] = 16'h10BA; hanning_window[ 242] = 16'h10DC; hanning_window[ 243] = 16'h10FE; hanning_window[ 244] = 16'h1120; hanning_window[ 245] = 16'h1143; hanning_window[ 246] = 16'h1165; hanning_window[ 247] = 16'h1188; 
    // 索引  248- 255
    hanning_window[ 248] = 16'h11AA; hanning_window[ 249] = 16'h11CD; hanning_window[ 250] = 16'h11F0; hanning_window[ 251] = 16'h1213; hanning_window[ 252] = 16'h1236; hanning_window[ 253] = 16'h1259; hanning_window[ 254] = 16'h127C; hanning_window[ 255] = 16'h12A0; 
    // 索引  256- 263
    hanning_window[ 256] = 16'h12C3; hanning_window[ 257] = 16'h12E7; hanning_window[ 258] = 16'h130B; hanning_window[ 259] = 16'h132E; hanning_window[ 260] = 16'h1352; hanning_window[ 261] = 16'h1376; hanning_window[ 262] = 16'h139B; hanning_window[ 263] = 16'h13BF; 
    // 索引  264- 271
    hanning_window[ 264] = 16'h13E3; hanning_window[ 265] = 16'h1408; hanning_window[ 266] = 16'h142C; hanning_window[ 267] = 16'h1451; hanning_window[ 268] = 16'h1476; hanning_window[ 269] = 16'h149B; hanning_window[ 270] = 16'h14C0; hanning_window[ 271] = 16'h14E5; 
    // 索引  272- 279
    hanning_window[ 272] = 16'h150A; hanning_window[ 273] = 16'h152F; hanning_window[ 274] = 16'h1555; hanning_window[ 275] = 16'h157A; hanning_window[ 276] = 16'h15A0; hanning_window[ 277] = 16'h15C6; hanning_window[ 278] = 16'h15EC; hanning_window[ 279] = 16'h1612; 
    // 索引  280- 287
    hanning_window[ 280] = 16'h1638; hanning_window[ 281] = 16'h165E; hanning_window[ 282] = 16'h1684; hanning_window[ 283] = 16'h16AA; hanning_window[ 284] = 16'h16D1; hanning_window[ 285] = 16'h16F7; hanning_window[ 286] = 16'h171E; hanning_window[ 287] = 16'h1745; 
    // 索引  288- 295
    hanning_window[ 288] = 16'h176C; hanning_window[ 289] = 16'h1793; hanning_window[ 290] = 16'h17BA; hanning_window[ 291] = 16'h17E1; hanning_window[ 292] = 16'h1808; hanning_window[ 293] = 16'h182F; hanning_window[ 294] = 16'h1857; hanning_window[ 295] = 16'h187E; 
    // 索引  296- 303
    hanning_window[ 296] = 16'h18A6; hanning_window[ 297] = 16'h18CD; hanning_window[ 298] = 16'h18F5; hanning_window[ 299] = 16'h191D; hanning_window[ 300] = 16'h1945; hanning_window[ 301] = 16'h196D; hanning_window[ 302] = 16'h1995; hanning_window[ 303] = 16'h19BE; 
    // 索引  304- 311
    hanning_window[ 304] = 16'h19E6; hanning_window[ 305] = 16'h1A0F; hanning_window[ 306] = 16'h1A37; hanning_window[ 307] = 16'h1A60; hanning_window[ 308] = 16'h1A88; hanning_window[ 309] = 16'h1AB1; hanning_window[ 310] = 16'h1ADA; hanning_window[ 311] = 16'h1B03; 
    // 索引  312- 319
    hanning_window[ 312] = 16'h1B2C; hanning_window[ 313] = 16'h1B55; hanning_window[ 314] = 16'h1B7F; hanning_window[ 315] = 16'h1BA8; hanning_window[ 316] = 16'h1BD1; hanning_window[ 317] = 16'h1BFB; hanning_window[ 318] = 16'h1C25; hanning_window[ 319] = 16'h1C4E; 
    // 索引  320- 327
    hanning_window[ 320] = 16'h1C78; hanning_window[ 321] = 16'h1CA2; hanning_window[ 322] = 16'h1CCC; hanning_window[ 323] = 16'h1CF6; hanning_window[ 324] = 16'h1D20; hanning_window[ 325] = 16'h1D4A; hanning_window[ 326] = 16'h1D75; hanning_window[ 327] = 16'h1D9F; 
    // 索引  328- 335
    hanning_window[ 328] = 16'h1DC9; hanning_window[ 329] = 16'h1DF4; hanning_window[ 330] = 16'h1E1F; hanning_window[ 331] = 16'h1E49; hanning_window[ 332] = 16'h1E74; hanning_window[ 333] = 16'h1E9F; hanning_window[ 334] = 16'h1ECA; hanning_window[ 335] = 16'h1EF5; 
    // 索引  336- 343
    hanning_window[ 336] = 16'h1F20; hanning_window[ 337] = 16'h1F4B; hanning_window[ 338] = 16'h1F76; hanning_window[ 339] = 16'h1FA2; hanning_window[ 340] = 16'h1FCD; hanning_window[ 341] = 16'h1FF9; hanning_window[ 342] = 16'h2024; hanning_window[ 343] = 16'h2050; 
    // 索引  344- 351
    hanning_window[ 344] = 16'h207C; hanning_window[ 345] = 16'h20A8; hanning_window[ 346] = 16'h20D3; hanning_window[ 347] = 16'h20FF; hanning_window[ 348] = 16'h212B; hanning_window[ 349] = 16'h2157; hanning_window[ 350] = 16'h2184; hanning_window[ 351] = 16'h21B0; 
    // 索引  352- 359
    hanning_window[ 352] = 16'h21DC; hanning_window[ 353] = 16'h2209; hanning_window[ 354] = 16'h2235; hanning_window[ 355] = 16'h2262; hanning_window[ 356] = 16'h228E; hanning_window[ 357] = 16'h22BB; hanning_window[ 358] = 16'h22E8; hanning_window[ 359] = 16'h2315; 
    // 索引  360- 367
    hanning_window[ 360] = 16'h2341; hanning_window[ 361] = 16'h236E; hanning_window[ 362] = 16'h239B; hanning_window[ 363] = 16'h23C9; hanning_window[ 364] = 16'h23F6; hanning_window[ 365] = 16'h2423; hanning_window[ 366] = 16'h2450; hanning_window[ 367] = 16'h247E; 
    // 索引  368- 375
    hanning_window[ 368] = 16'h24AB; hanning_window[ 369] = 16'h24D9; hanning_window[ 370] = 16'h2506; hanning_window[ 371] = 16'h2534; hanning_window[ 372] = 16'h2562; hanning_window[ 373] = 16'h258F; hanning_window[ 374] = 16'h25BD; hanning_window[ 375] = 16'h25EB; 
    // 索引  376- 383
    hanning_window[ 376] = 16'h2619; hanning_window[ 377] = 16'h2647; hanning_window[ 378] = 16'h2675; hanning_window[ 379] = 16'h26A3; hanning_window[ 380] = 16'h26D1; hanning_window[ 381] = 16'h2700; hanning_window[ 382] = 16'h272E; hanning_window[ 383] = 16'h275C; 
    // 索引  384- 391
    hanning_window[ 384] = 16'h278B; hanning_window[ 385] = 16'h27B9; hanning_window[ 386] = 16'h27E8; hanning_window[ 387] = 16'h2817; hanning_window[ 388] = 16'h2845; hanning_window[ 389] = 16'h2874; hanning_window[ 390] = 16'h28A3; hanning_window[ 391] = 16'h28D2; 
    // 索引  392- 399
    hanning_window[ 392] = 16'h2900; hanning_window[ 393] = 16'h292F; hanning_window[ 394] = 16'h295E; hanning_window[ 395] = 16'h298E; hanning_window[ 396] = 16'h29BD; hanning_window[ 397] = 16'h29EC; hanning_window[ 398] = 16'h2A1B; hanning_window[ 399] = 16'h2A4A; 
    // 索引  400- 407
    hanning_window[ 400] = 16'h2A7A; hanning_window[ 401] = 16'h2AA9; hanning_window[ 402] = 16'h2AD8; hanning_window[ 403] = 16'h2B08; hanning_window[ 404] = 16'h2B37; hanning_window[ 405] = 16'h2B67; hanning_window[ 406] = 16'h2B97; hanning_window[ 407] = 16'h2BC6; 
    // 索引  408- 415
    hanning_window[ 408] = 16'h2BF6; hanning_window[ 409] = 16'h2C26; hanning_window[ 410] = 16'h2C56; hanning_window[ 411] = 16'h2C86; hanning_window[ 412] = 16'h2CB6; hanning_window[ 413] = 16'h2CE6; hanning_window[ 414] = 16'h2D16; hanning_window[ 415] = 16'h2D46; 
    // 索引  416- 423
    hanning_window[ 416] = 16'h2D76; hanning_window[ 417] = 16'h2DA6; hanning_window[ 418] = 16'h2DD6; hanning_window[ 419] = 16'h2E06; hanning_window[ 420] = 16'h2E37; hanning_window[ 421] = 16'h2E67; hanning_window[ 422] = 16'h2E97; hanning_window[ 423] = 16'h2EC8; 
    // 索引  424- 431
    hanning_window[ 424] = 16'h2EF8; hanning_window[ 425] = 16'h2F29; hanning_window[ 426] = 16'h2F59; hanning_window[ 427] = 16'h2F8A; hanning_window[ 428] = 16'h2FBA; hanning_window[ 429] = 16'h2FEB; hanning_window[ 430] = 16'h301C; hanning_window[ 431] = 16'h304D; 
    // 索引  432- 439
    hanning_window[ 432] = 16'h307D; hanning_window[ 433] = 16'h30AE; hanning_window[ 434] = 16'h30DF; hanning_window[ 435] = 16'h3110; hanning_window[ 436] = 16'h3141; hanning_window[ 437] = 16'h3172; hanning_window[ 438] = 16'h31A3; hanning_window[ 439] = 16'h31D4; 
    // 索引  440- 447
    hanning_window[ 440] = 16'h3205; hanning_window[ 441] = 16'h3236; hanning_window[ 442] = 16'h3267; hanning_window[ 443] = 16'h3298; hanning_window[ 444] = 16'h32C9; hanning_window[ 445] = 16'h32FB; hanning_window[ 446] = 16'h332C; hanning_window[ 447] = 16'h335D; 
    // 索引  448- 455
    hanning_window[ 448] = 16'h338E; hanning_window[ 449] = 16'h33C0; hanning_window[ 450] = 16'h33F1; hanning_window[ 451] = 16'h3423; hanning_window[ 452] = 16'h3454; hanning_window[ 453] = 16'h3485; hanning_window[ 454] = 16'h34B7; hanning_window[ 455] = 16'h34E8; 
    // 索引  456- 463
    hanning_window[ 456] = 16'h351A; hanning_window[ 457] = 16'h354C; hanning_window[ 458] = 16'h357D; hanning_window[ 459] = 16'h35AF; hanning_window[ 460] = 16'h35E0; hanning_window[ 461] = 16'h3612; hanning_window[ 462] = 16'h3644; hanning_window[ 463] = 16'h3675; 
    // 索引  464- 471
    hanning_window[ 464] = 16'h36A7; hanning_window[ 465] = 16'h36D9; hanning_window[ 466] = 16'h370B; hanning_window[ 467] = 16'h373D; hanning_window[ 468] = 16'h376E; hanning_window[ 469] = 16'h37A0; hanning_window[ 470] = 16'h37D2; hanning_window[ 471] = 16'h3804; 
    // 索引  472- 479
    hanning_window[ 472] = 16'h3836; hanning_window[ 473] = 16'h3868; hanning_window[ 474] = 16'h389A; hanning_window[ 475] = 16'h38CC; hanning_window[ 476] = 16'h38FE; hanning_window[ 477] = 16'h3930; hanning_window[ 478] = 16'h3962; hanning_window[ 479] = 16'h3994; 
    // 索引  480- 487
    hanning_window[ 480] = 16'h39C6; hanning_window[ 481] = 16'h39F8; hanning_window[ 482] = 16'h3A2A; hanning_window[ 483] = 16'h3A5C; hanning_window[ 484] = 16'h3A8E; hanning_window[ 485] = 16'h3AC0; hanning_window[ 486] = 16'h3AF2; hanning_window[ 487] = 16'h3B25; 
    // 索引  488- 495
    hanning_window[ 488] = 16'h3B57; hanning_window[ 489] = 16'h3B89; hanning_window[ 490] = 16'h3BBB; hanning_window[ 491] = 16'h3BED; hanning_window[ 492] = 16'h3C1F; hanning_window[ 493] = 16'h3C52; hanning_window[ 494] = 16'h3C84; hanning_window[ 495] = 16'h3CB6; 
    // 索引  496- 503
    hanning_window[ 496] = 16'h3CE8; hanning_window[ 497] = 16'h3D1A; hanning_window[ 498] = 16'h3D4D; hanning_window[ 499] = 16'h3D7F; hanning_window[ 500] = 16'h3DB1; hanning_window[ 501] = 16'h3DE3; hanning_window[ 502] = 16'h3E16; hanning_window[ 503] = 16'h3E48; 
    // 索引  504- 511
    hanning_window[ 504] = 16'h3E7A; hanning_window[ 505] = 16'h3EAD; hanning_window[ 506] = 16'h3EDF; hanning_window[ 507] = 16'h3F11; hanning_window[ 508] = 16'h3F43; hanning_window[ 509] = 16'h3F76; hanning_window[ 510] = 16'h3FA8; hanning_window[ 511] = 16'h3FDA; 
    // 索引  512- 519
    hanning_window[ 512] = 16'h400D; hanning_window[ 513] = 16'h403F; hanning_window[ 514] = 16'h4071; hanning_window[ 515] = 16'h40A3; hanning_window[ 516] = 16'h40D6; hanning_window[ 517] = 16'h4108; hanning_window[ 518] = 16'h413A; hanning_window[ 519] = 16'h416D; 
    // 索引  520- 527
    hanning_window[ 520] = 16'h419F; hanning_window[ 521] = 16'h41D1; hanning_window[ 522] = 16'h4203; hanning_window[ 523] = 16'h4236; hanning_window[ 524] = 16'h4268; hanning_window[ 525] = 16'h429A; hanning_window[ 526] = 16'h42CC; hanning_window[ 527] = 16'h42FF; 
    // 索引  528- 535
    hanning_window[ 528] = 16'h4331; hanning_window[ 529] = 16'h4363; hanning_window[ 530] = 16'h4395; hanning_window[ 531] = 16'h43C8; hanning_window[ 532] = 16'h43FA; hanning_window[ 533] = 16'h442C; hanning_window[ 534] = 16'h445E; hanning_window[ 535] = 16'h4490; 
    // 索引  536- 543
    hanning_window[ 536] = 16'h44C2; hanning_window[ 537] = 16'h44F5; hanning_window[ 538] = 16'h4527; hanning_window[ 539] = 16'h4559; hanning_window[ 540] = 16'h458B; hanning_window[ 541] = 16'h45BD; hanning_window[ 542] = 16'h45EF; hanning_window[ 543] = 16'h4621; 
    // 索引  544- 551
    hanning_window[ 544] = 16'h4653; hanning_window[ 545] = 16'h4685; hanning_window[ 546] = 16'h46B7; hanning_window[ 547] = 16'h46E9; hanning_window[ 548] = 16'h471B; hanning_window[ 549] = 16'h474D; hanning_window[ 550] = 16'h477F; hanning_window[ 551] = 16'h47B1; 
    // 索引  552- 559
    hanning_window[ 552] = 16'h47E3; hanning_window[ 553] = 16'h4815; hanning_window[ 554] = 16'h4847; hanning_window[ 555] = 16'h4879; hanning_window[ 556] = 16'h48AA; hanning_window[ 557] = 16'h48DC; hanning_window[ 558] = 16'h490E; hanning_window[ 559] = 16'h4940; 
    // 索引  560- 567
    hanning_window[ 560] = 16'h4972; hanning_window[ 561] = 16'h49A3; hanning_window[ 562] = 16'h49D5; hanning_window[ 563] = 16'h4A07; hanning_window[ 564] = 16'h4A38; hanning_window[ 565] = 16'h4A6A; hanning_window[ 566] = 16'h4A9C; hanning_window[ 567] = 16'h4ACD; 
    // 索引  568- 575
    hanning_window[ 568] = 16'h4AFF; hanning_window[ 569] = 16'h4B30; hanning_window[ 570] = 16'h4B62; hanning_window[ 571] = 16'h4B93; hanning_window[ 572] = 16'h4BC5; hanning_window[ 573] = 16'h4BF6; hanning_window[ 574] = 16'h4C28; hanning_window[ 575] = 16'h4C59; 
    // 索引  576- 583
    hanning_window[ 576] = 16'h4C8A; hanning_window[ 577] = 16'h4CBC; hanning_window[ 578] = 16'h4CED; hanning_window[ 579] = 16'h4D1E; hanning_window[ 580] = 16'h4D4F; hanning_window[ 581] = 16'h4D80; hanning_window[ 582] = 16'h4DB2; hanning_window[ 583] = 16'h4DE3; 
    // 索引  584- 591
    hanning_window[ 584] = 16'h4E14; hanning_window[ 585] = 16'h4E45; hanning_window[ 586] = 16'h4E76; hanning_window[ 587] = 16'h4EA7; hanning_window[ 588] = 16'h4ED8; hanning_window[ 589] = 16'h4F09; hanning_window[ 590] = 16'h4F39; hanning_window[ 591] = 16'h4F6A; 
    // 索引  592- 599
    hanning_window[ 592] = 16'h4F9B; hanning_window[ 593] = 16'h4FCC; hanning_window[ 594] = 16'h4FFD; hanning_window[ 595] = 16'h502D; hanning_window[ 596] = 16'h505E; hanning_window[ 597] = 16'h508E; hanning_window[ 598] = 16'h50BF; hanning_window[ 599] = 16'h50F0; 
    // 索引  600- 607
    hanning_window[ 600] = 16'h5120; hanning_window[ 601] = 16'h5150; hanning_window[ 602] = 16'h5181; hanning_window[ 603] = 16'h51B1; hanning_window[ 604] = 16'h51E2; hanning_window[ 605] = 16'h5212; hanning_window[ 606] = 16'h5242; hanning_window[ 607] = 16'h5272; 
    // 索引  608- 615
    hanning_window[ 608] = 16'h52A2; hanning_window[ 609] = 16'h52D2; hanning_window[ 610] = 16'h5302; hanning_window[ 611] = 16'h5332; hanning_window[ 612] = 16'h5362; hanning_window[ 613] = 16'h5392; hanning_window[ 614] = 16'h53C2; hanning_window[ 615] = 16'h53F2; 
    // 索引  616- 623
    hanning_window[ 616] = 16'h5422; hanning_window[ 617] = 16'h5451; hanning_window[ 618] = 16'h5481; hanning_window[ 619] = 16'h54B1; hanning_window[ 620] = 16'h54E0; hanning_window[ 621] = 16'h5510; hanning_window[ 622] = 16'h553F; hanning_window[ 623] = 16'h556F; 
    // 索引  624- 631
    hanning_window[ 624] = 16'h559E; hanning_window[ 625] = 16'h55CD; hanning_window[ 626] = 16'h55FD; hanning_window[ 627] = 16'h562C; hanning_window[ 628] = 16'h565B; hanning_window[ 629] = 16'h568A; hanning_window[ 630] = 16'h56B9; hanning_window[ 631] = 16'h56E8; 
    // 索引  632- 639
    hanning_window[ 632] = 16'h5717; hanning_window[ 633] = 16'h5746; hanning_window[ 634] = 16'h5775; hanning_window[ 635] = 16'h57A3; hanning_window[ 636] = 16'h57D2; hanning_window[ 637] = 16'h5801; hanning_window[ 638] = 16'h582F; hanning_window[ 639] = 16'h585E; 
    // 索引  640- 647
    hanning_window[ 640] = 16'h588C; hanning_window[ 641] = 16'h58BB; hanning_window[ 642] = 16'h58E9; hanning_window[ 643] = 16'h5917; hanning_window[ 644] = 16'h5946; hanning_window[ 645] = 16'h5974; hanning_window[ 646] = 16'h59A2; hanning_window[ 647] = 16'h59D0; 
    // 索引  648- 655
    hanning_window[ 648] = 16'h59FE; hanning_window[ 649] = 16'h5A2C; hanning_window[ 650] = 16'h5A5A; hanning_window[ 651] = 16'h5A88; hanning_window[ 652] = 16'h5AB5; hanning_window[ 653] = 16'h5AE3; hanning_window[ 654] = 16'h5B11; hanning_window[ 655] = 16'h5B3E; 
    // 索引  656- 663
    hanning_window[ 656] = 16'h5B6C; hanning_window[ 657] = 16'h5B99; hanning_window[ 658] = 16'h5BC6; hanning_window[ 659] = 16'h5BF4; hanning_window[ 660] = 16'h5C21; hanning_window[ 661] = 16'h5C4E; hanning_window[ 662] = 16'h5C7B; hanning_window[ 663] = 16'h5CA8; 
    // 索引  664- 671
    hanning_window[ 664] = 16'h5CD5; hanning_window[ 665] = 16'h5D02; hanning_window[ 666] = 16'h5D2F; hanning_window[ 667] = 16'h5D5B; hanning_window[ 668] = 16'h5D88; hanning_window[ 669] = 16'h5DB5; hanning_window[ 670] = 16'h5DE1; hanning_window[ 671] = 16'h5E0E; 
    // 索引  672- 679
    hanning_window[ 672] = 16'h5E3A; hanning_window[ 673] = 16'h5E66; hanning_window[ 674] = 16'h5E92; hanning_window[ 675] = 16'h5EBF; hanning_window[ 676] = 16'h5EEB; hanning_window[ 677] = 16'h5F17; hanning_window[ 678] = 16'h5F43; hanning_window[ 679] = 16'h5F6E; 
    // 索引  680- 687
    hanning_window[ 680] = 16'h5F9A; hanning_window[ 681] = 16'h5FC6; hanning_window[ 682] = 16'h5FF1; hanning_window[ 683] = 16'h601D; hanning_window[ 684] = 16'h6048; hanning_window[ 685] = 16'h6074; hanning_window[ 686] = 16'h609F; hanning_window[ 687] = 16'h60CA; 
    // 索引  688- 695
    hanning_window[ 688] = 16'h60F6; hanning_window[ 689] = 16'h6121; hanning_window[ 690] = 16'h614C; hanning_window[ 691] = 16'h6177; hanning_window[ 692] = 16'h61A1; hanning_window[ 693] = 16'h61CC; hanning_window[ 694] = 16'h61F7; hanning_window[ 695] = 16'h6221; 
    // 索引  696- 703
    hanning_window[ 696] = 16'h624C; hanning_window[ 697] = 16'h6276; hanning_window[ 698] = 16'h62A1; hanning_window[ 699] = 16'h62CB; hanning_window[ 700] = 16'h62F5; hanning_window[ 701] = 16'h631F; hanning_window[ 702] = 16'h6349; hanning_window[ 703] = 16'h6373; 
    // 索引  704- 711
    hanning_window[ 704] = 16'h639D; hanning_window[ 705] = 16'h63C7; hanning_window[ 706] = 16'h63F0; hanning_window[ 707] = 16'h641A; hanning_window[ 708] = 16'h6443; hanning_window[ 709] = 16'h646D; hanning_window[ 710] = 16'h6496; hanning_window[ 711] = 16'h64BF; 
    // 索引  712- 719
    hanning_window[ 712] = 16'h64E8; hanning_window[ 713] = 16'h6511; hanning_window[ 714] = 16'h653A; hanning_window[ 715] = 16'h6563; hanning_window[ 716] = 16'h658C; hanning_window[ 717] = 16'h65B5; hanning_window[ 718] = 16'h65DD; hanning_window[ 719] = 16'h6606; 
    // 索引  720- 727
    hanning_window[ 720] = 16'h662E; hanning_window[ 721] = 16'h6656; hanning_window[ 722] = 16'h667F; hanning_window[ 723] = 16'h66A7; hanning_window[ 724] = 16'h66CF; hanning_window[ 725] = 16'h66F7; hanning_window[ 726] = 16'h671F; hanning_window[ 727] = 16'h6746; 
    // 索引  728- 735
    hanning_window[ 728] = 16'h676E; hanning_window[ 729] = 16'h6796; hanning_window[ 730] = 16'h67BD; hanning_window[ 731] = 16'h67E4; hanning_window[ 732] = 16'h680C; hanning_window[ 733] = 16'h6833; hanning_window[ 734] = 16'h685A; hanning_window[ 735] = 16'h6881; 
    // 索引  736- 743
    hanning_window[ 736] = 16'h68A8; hanning_window[ 737] = 16'h68CF; hanning_window[ 738] = 16'h68F5; hanning_window[ 739] = 16'h691C; hanning_window[ 740] = 16'h6942; hanning_window[ 741] = 16'h6969; hanning_window[ 742] = 16'h698F; hanning_window[ 743] = 16'h69B5; 
    // 索引  744- 751
    hanning_window[ 744] = 16'h69DB; hanning_window[ 745] = 16'h6A01; hanning_window[ 746] = 16'h6A27; hanning_window[ 747] = 16'h6A4D; hanning_window[ 748] = 16'h6A73; hanning_window[ 749] = 16'h6A98; hanning_window[ 750] = 16'h6ABE; hanning_window[ 751] = 16'h6AE3; 
    // 索引  752- 759
    hanning_window[ 752] = 16'h6B08; hanning_window[ 753] = 16'h6B2E; hanning_window[ 754] = 16'h6B53; hanning_window[ 755] = 16'h6B78; hanning_window[ 756] = 16'h6B9D; hanning_window[ 757] = 16'h6BC1; hanning_window[ 758] = 16'h6BE6; hanning_window[ 759] = 16'h6C0B; 
    // 索引  760- 767
    hanning_window[ 760] = 16'h6C2F; hanning_window[ 761] = 16'h6C53; hanning_window[ 762] = 16'h6C77; hanning_window[ 763] = 16'h6C9C; hanning_window[ 764] = 16'h6CC0; hanning_window[ 765] = 16'h6CE4; hanning_window[ 766] = 16'h6D07; hanning_window[ 767] = 16'h6D2B; 
    // 索引  768- 775
    hanning_window[ 768] = 16'h6D4F; hanning_window[ 769] = 16'h6D72; hanning_window[ 770] = 16'h6D95; hanning_window[ 771] = 16'h6DB9; hanning_window[ 772] = 16'h6DDC; hanning_window[ 773] = 16'h6DFF; hanning_window[ 774] = 16'h6E22; hanning_window[ 775] = 16'h6E45; 
    // 索引  776- 783
    hanning_window[ 776] = 16'h6E67; hanning_window[ 777] = 16'h6E8A; hanning_window[ 778] = 16'h6EAC; hanning_window[ 779] = 16'h6ECF; hanning_window[ 780] = 16'h6EF1; hanning_window[ 781] = 16'h6F13; hanning_window[ 782] = 16'h6F35; hanning_window[ 783] = 16'h6F57; 
    // 索引  784- 791
    hanning_window[ 784] = 16'h6F79; hanning_window[ 785] = 16'h6F9A; hanning_window[ 786] = 16'h6FBC; hanning_window[ 787] = 16'h6FDD; hanning_window[ 788] = 16'h6FFF; hanning_window[ 789] = 16'h7020; hanning_window[ 790] = 16'h7041; hanning_window[ 791] = 16'h7062; 
    // 索引  792- 799
    hanning_window[ 792] = 16'h7083; hanning_window[ 793] = 16'h70A4; hanning_window[ 794] = 16'h70C4; hanning_window[ 795] = 16'h70E5; hanning_window[ 796] = 16'h7105; hanning_window[ 797] = 16'h7125; hanning_window[ 798] = 16'h7146; hanning_window[ 799] = 16'h7166; 
    // 索引  800- 807
    hanning_window[ 800] = 16'h7185; hanning_window[ 801] = 16'h71A5; hanning_window[ 802] = 16'h71C5; hanning_window[ 803] = 16'h71E4; hanning_window[ 804] = 16'h7204; hanning_window[ 805] = 16'h7223; hanning_window[ 806] = 16'h7242; hanning_window[ 807] = 16'h7262; 
    // 索引  808- 815
    hanning_window[ 808] = 16'h7280; hanning_window[ 809] = 16'h729F; hanning_window[ 810] = 16'h72BE; hanning_window[ 811] = 16'h72DD; hanning_window[ 812] = 16'h72FB; hanning_window[ 813] = 16'h7319; hanning_window[ 814] = 16'h7338; hanning_window[ 815] = 16'h7356; 
    // 索引  816- 823
    hanning_window[ 816] = 16'h7374; hanning_window[ 817] = 16'h7392; hanning_window[ 818] = 16'h73AF; hanning_window[ 819] = 16'h73CD; hanning_window[ 820] = 16'h73EA; hanning_window[ 821] = 16'h7408; hanning_window[ 822] = 16'h7425; hanning_window[ 823] = 16'h7442; 
    // 索引  824- 831
    hanning_window[ 824] = 16'h745F; hanning_window[ 825] = 16'h747C; hanning_window[ 826] = 16'h7499; hanning_window[ 827] = 16'h74B5; hanning_window[ 828] = 16'h74D2; hanning_window[ 829] = 16'h74EE; hanning_window[ 830] = 16'h750A; hanning_window[ 831] = 16'h7526; 
    // 索引  832- 839
    hanning_window[ 832] = 16'h7542; hanning_window[ 833] = 16'h755E; hanning_window[ 834] = 16'h757A; hanning_window[ 835] = 16'h7595; hanning_window[ 836] = 16'h75B1; hanning_window[ 837] = 16'h75CC; hanning_window[ 838] = 16'h75E7; hanning_window[ 839] = 16'h7602; 
    // 索引  840- 847
    hanning_window[ 840] = 16'h761D; hanning_window[ 841] = 16'h7638; hanning_window[ 842] = 16'h7653; hanning_window[ 843] = 16'h766D; hanning_window[ 844] = 16'h7687; hanning_window[ 845] = 16'h76A2; hanning_window[ 846] = 16'h76BC; hanning_window[ 847] = 16'h76D6; 
    // 索引  848- 855
    hanning_window[ 848] = 16'h76F0; hanning_window[ 849] = 16'h7709; hanning_window[ 850] = 16'h7723; hanning_window[ 851] = 16'h773D; hanning_window[ 852] = 16'h7756; hanning_window[ 853] = 16'h776F; hanning_window[ 854] = 16'h7788; hanning_window[ 855] = 16'h77A1; 
    // 索引  856- 863
    hanning_window[ 856] = 16'h77BA; hanning_window[ 857] = 16'h77D3; hanning_window[ 858] = 16'h77EB; hanning_window[ 859] = 16'h7803; hanning_window[ 860] = 16'h781C; hanning_window[ 861] = 16'h7834; hanning_window[ 862] = 16'h784C; hanning_window[ 863] = 16'h7864; 
    // 索引  864- 871
    hanning_window[ 864] = 16'h787B; hanning_window[ 865] = 16'h7893; hanning_window[ 866] = 16'h78AA; hanning_window[ 867] = 16'h78C2; hanning_window[ 868] = 16'h78D9; hanning_window[ 869] = 16'h78F0; hanning_window[ 870] = 16'h7907; hanning_window[ 871] = 16'h791E; 
    // 索引  872- 879
    hanning_window[ 872] = 16'h7934; hanning_window[ 873] = 16'h794B; hanning_window[ 874] = 16'h7961; hanning_window[ 875] = 16'h7977; hanning_window[ 876] = 16'h798D; hanning_window[ 877] = 16'h79A3; hanning_window[ 878] = 16'h79B9; hanning_window[ 879] = 16'h79CF; 
    // 索引  880- 887
    hanning_window[ 880] = 16'h79E4; hanning_window[ 881] = 16'h79FA; hanning_window[ 882] = 16'h7A0F; hanning_window[ 883] = 16'h7A24; hanning_window[ 884] = 16'h7A39; hanning_window[ 885] = 16'h7A4E; hanning_window[ 886] = 16'h7A62; hanning_window[ 887] = 16'h7A77; 
    // 索引  888- 895
    hanning_window[ 888] = 16'h7A8B; hanning_window[ 889] = 16'h7A9F; hanning_window[ 890] = 16'h7AB4; hanning_window[ 891] = 16'h7AC8; hanning_window[ 892] = 16'h7ADB; hanning_window[ 893] = 16'h7AEF; hanning_window[ 894] = 16'h7B03; hanning_window[ 895] = 16'h7B16; 
    // 索引  896- 903
    hanning_window[ 896] = 16'h7B29; hanning_window[ 897] = 16'h7B3C; hanning_window[ 898] = 16'h7B4F; hanning_window[ 899] = 16'h7B62; hanning_window[ 900] = 16'h7B75; hanning_window[ 901] = 16'h7B87; hanning_window[ 902] = 16'h7B9A; hanning_window[ 903] = 16'h7BAC; 
    // 索引  904- 911
    hanning_window[ 904] = 16'h7BBE; hanning_window[ 905] = 16'h7BD0; hanning_window[ 906] = 16'h7BE2; hanning_window[ 907] = 16'h7BF4; hanning_window[ 908] = 16'h7C05; hanning_window[ 909] = 16'h7C17; hanning_window[ 910] = 16'h7C28; hanning_window[ 911] = 16'h7C39; 
    // 索引  912- 919
    hanning_window[ 912] = 16'h7C4A; hanning_window[ 913] = 16'h7C5B; hanning_window[ 914] = 16'h7C6B; hanning_window[ 915] = 16'h7C7C; hanning_window[ 916] = 16'h7C8C; hanning_window[ 917] = 16'h7C9C; hanning_window[ 918] = 16'h7CAC; hanning_window[ 919] = 16'h7CBC; 
    // 索引  920- 927
    hanning_window[ 920] = 16'h7CCC; hanning_window[ 921] = 16'h7CDC; hanning_window[ 922] = 16'h7CEB; hanning_window[ 923] = 16'h7CFB; hanning_window[ 924] = 16'h7D0A; hanning_window[ 925] = 16'h7D19; hanning_window[ 926] = 16'h7D28; hanning_window[ 927] = 16'h7D37; 
    // 索引  928- 935
    hanning_window[ 928] = 16'h7D45; hanning_window[ 929] = 16'h7D54; hanning_window[ 930] = 16'h7D62; hanning_window[ 931] = 16'h7D70; hanning_window[ 932] = 16'h7D7E; hanning_window[ 933] = 16'h7D8C; hanning_window[ 934] = 16'h7D9A; hanning_window[ 935] = 16'h7DA7; 
    // 索引  936- 943
    hanning_window[ 936] = 16'h7DB5; hanning_window[ 937] = 16'h7DC2; hanning_window[ 938] = 16'h7DCF; hanning_window[ 939] = 16'h7DDC; hanning_window[ 940] = 16'h7DE9; hanning_window[ 941] = 16'h7DF5; hanning_window[ 942] = 16'h7E02; hanning_window[ 943] = 16'h7E0E; 
    // 索引  944- 951
    hanning_window[ 944] = 16'h7E1B; hanning_window[ 945] = 16'h7E27; hanning_window[ 946] = 16'h7E33; hanning_window[ 947] = 16'h7E3E; hanning_window[ 948] = 16'h7E4A; hanning_window[ 949] = 16'h7E55; hanning_window[ 950] = 16'h7E61; hanning_window[ 951] = 16'h7E6C; 
    // 索引  952- 959
    hanning_window[ 952] = 16'h7E77; hanning_window[ 953] = 16'h7E82; hanning_window[ 954] = 16'h7E8D; hanning_window[ 955] = 16'h7E97; hanning_window[ 956] = 16'h7EA2; hanning_window[ 957] = 16'h7EAC; hanning_window[ 958] = 16'h7EB6; hanning_window[ 959] = 16'h7EC0; 
    // 索引  960- 967
    hanning_window[ 960] = 16'h7ECA; hanning_window[ 961] = 16'h7ED3; hanning_window[ 962] = 16'h7EDD; hanning_window[ 963] = 16'h7EE6; hanning_window[ 964] = 16'h7EF0; hanning_window[ 965] = 16'h7EF9; hanning_window[ 966] = 16'h7F01; hanning_window[ 967] = 16'h7F0A; 
    // 索引  968- 975
    hanning_window[ 968] = 16'h7F13; hanning_window[ 969] = 16'h7F1B; hanning_window[ 970] = 16'h7F24; hanning_window[ 971] = 16'h7F2C; hanning_window[ 972] = 16'h7F34; hanning_window[ 973] = 16'h7F3C; hanning_window[ 974] = 16'h7F43; hanning_window[ 975] = 16'h7F4B; 
    // 索引  976- 983
    hanning_window[ 976] = 16'h7F52; hanning_window[ 977] = 16'h7F59; hanning_window[ 978] = 16'h7F60; hanning_window[ 979] = 16'h7F67; hanning_window[ 980] = 16'h7F6E; hanning_window[ 981] = 16'h7F75; hanning_window[ 982] = 16'h7F7B; hanning_window[ 983] = 16'h7F82; 
    // 索引  984- 991
    hanning_window[ 984] = 16'h7F88; hanning_window[ 985] = 16'h7F8E; hanning_window[ 986] = 16'h7F94; hanning_window[ 987] = 16'h7F99; hanning_window[ 988] = 16'h7F9F; hanning_window[ 989] = 16'h7FA4; hanning_window[ 990] = 16'h7FA9; hanning_window[ 991] = 16'h7FAF; 
    // 索引  992- 999
    hanning_window[ 992] = 16'h7FB3; hanning_window[ 993] = 16'h7FB8; hanning_window[ 994] = 16'h7FBD; hanning_window[ 995] = 16'h7FC1; hanning_window[ 996] = 16'h7FC6; hanning_window[ 997] = 16'h7FCA; hanning_window[ 998] = 16'h7FCE; hanning_window[ 999] = 16'h7FD2; 
    // 索引 1000-1007
    hanning_window[1000] = 16'h7FD5; hanning_window[1001] = 16'h7FD9; hanning_window[1002] = 16'h7FDC; hanning_window[1003] = 16'h7FE0; hanning_window[1004] = 16'h7FE3; hanning_window[1005] = 16'h7FE6; hanning_window[1006] = 16'h7FE8; hanning_window[1007] = 16'h7FEB; 
    // 索引 1008-1015
    hanning_window[1008] = 16'h7FED; hanning_window[1009] = 16'h7FF0; hanning_window[1010] = 16'h7FF2; hanning_window[1011] = 16'h7FF4; hanning_window[1012] = 16'h7FF6; hanning_window[1013] = 16'h7FF7; hanning_window[1014] = 16'h7FF9; hanning_window[1015] = 16'h7FFA; 
    // 索引 1016-1023
    hanning_window[1016] = 16'h7FFC; hanning_window[1017] = 16'h7FFD; hanning_window[1018] = 16'h7FFE; hanning_window[1019] = 16'h7FFE; hanning_window[1020] = 16'h7FFF; hanning_window[1021] = 16'h8000; hanning_window[1022] = 16'h8000; hanning_window[1023] = 16'h8000; 
    // 索引 1024-1031
    hanning_window[1024] = 16'h8000; hanning_window[1025] = 16'h8000; hanning_window[1026] = 16'h8000; hanning_window[1027] = 16'h7FFF; hanning_window[1028] = 16'h7FFE; hanning_window[1029] = 16'h7FFE; hanning_window[1030] = 16'h7FFD; hanning_window[1031] = 16'h7FFC; 
    // 索引 1032-1039
    hanning_window[1032] = 16'h7FFA; hanning_window[1033] = 16'h7FF9; hanning_window[1034] = 16'h7FF7; hanning_window[1035] = 16'h7FF6; hanning_window[1036] = 16'h7FF4; hanning_window[1037] = 16'h7FF2; hanning_window[1038] = 16'h7FF0; hanning_window[1039] = 16'h7FED; 
    // 索引 1040-1047
    hanning_window[1040] = 16'h7FEB; hanning_window[1041] = 16'h7FE8; hanning_window[1042] = 16'h7FE6; hanning_window[1043] = 16'h7FE3; hanning_window[1044] = 16'h7FE0; hanning_window[1045] = 16'h7FDC; hanning_window[1046] = 16'h7FD9; hanning_window[1047] = 16'h7FD5; 
    // 索引 1048-1055
    hanning_window[1048] = 16'h7FD2; hanning_window[1049] = 16'h7FCE; hanning_window[1050] = 16'h7FCA; hanning_window[1051] = 16'h7FC6; hanning_window[1052] = 16'h7FC1; hanning_window[1053] = 16'h7FBD; hanning_window[1054] = 16'h7FB8; hanning_window[1055] = 16'h7FB3; 
    // 索引 1056-1063
    hanning_window[1056] = 16'h7FAF; hanning_window[1057] = 16'h7FA9; hanning_window[1058] = 16'h7FA4; hanning_window[1059] = 16'h7F9F; hanning_window[1060] = 16'h7F99; hanning_window[1061] = 16'h7F94; hanning_window[1062] = 16'h7F8E; hanning_window[1063] = 16'h7F88; 
    // 索引 1064-1071
    hanning_window[1064] = 16'h7F82; hanning_window[1065] = 16'h7F7B; hanning_window[1066] = 16'h7F75; hanning_window[1067] = 16'h7F6E; hanning_window[1068] = 16'h7F67; hanning_window[1069] = 16'h7F60; hanning_window[1070] = 16'h7F59; hanning_window[1071] = 16'h7F52; 
    // 索引 1072-1079
    hanning_window[1072] = 16'h7F4B; hanning_window[1073] = 16'h7F43; hanning_window[1074] = 16'h7F3C; hanning_window[1075] = 16'h7F34; hanning_window[1076] = 16'h7F2C; hanning_window[1077] = 16'h7F24; hanning_window[1078] = 16'h7F1B; hanning_window[1079] = 16'h7F13; 
    // 索引 1080-1087
    hanning_window[1080] = 16'h7F0A; hanning_window[1081] = 16'h7F01; hanning_window[1082] = 16'h7EF9; hanning_window[1083] = 16'h7EF0; hanning_window[1084] = 16'h7EE6; hanning_window[1085] = 16'h7EDD; hanning_window[1086] = 16'h7ED3; hanning_window[1087] = 16'h7ECA; 
    // 索引 1088-1095
    hanning_window[1088] = 16'h7EC0; hanning_window[1089] = 16'h7EB6; hanning_window[1090] = 16'h7EAC; hanning_window[1091] = 16'h7EA2; hanning_window[1092] = 16'h7E97; hanning_window[1093] = 16'h7E8D; hanning_window[1094] = 16'h7E82; hanning_window[1095] = 16'h7E77; 
    // 索引 1096-1103
    hanning_window[1096] = 16'h7E6C; hanning_window[1097] = 16'h7E61; hanning_window[1098] = 16'h7E55; hanning_window[1099] = 16'h7E4A; hanning_window[1100] = 16'h7E3E; hanning_window[1101] = 16'h7E33; hanning_window[1102] = 16'h7E27; hanning_window[1103] = 16'h7E1B; 
    // 索引 1104-1111
    hanning_window[1104] = 16'h7E0E; hanning_window[1105] = 16'h7E02; hanning_window[1106] = 16'h7DF5; hanning_window[1107] = 16'h7DE9; hanning_window[1108] = 16'h7DDC; hanning_window[1109] = 16'h7DCF; hanning_window[1110] = 16'h7DC2; hanning_window[1111] = 16'h7DB5; 
    // 索引 1112-1119
    hanning_window[1112] = 16'h7DA7; hanning_window[1113] = 16'h7D9A; hanning_window[1114] = 16'h7D8C; hanning_window[1115] = 16'h7D7E; hanning_window[1116] = 16'h7D70; hanning_window[1117] = 16'h7D62; hanning_window[1118] = 16'h7D54; hanning_window[1119] = 16'h7D45; 
    // 索引 1120-1127
    hanning_window[1120] = 16'h7D37; hanning_window[1121] = 16'h7D28; hanning_window[1122] = 16'h7D19; hanning_window[1123] = 16'h7D0A; hanning_window[1124] = 16'h7CFB; hanning_window[1125] = 16'h7CEB; hanning_window[1126] = 16'h7CDC; hanning_window[1127] = 16'h7CCC; 
    // 索引 1128-1135
    hanning_window[1128] = 16'h7CBC; hanning_window[1129] = 16'h7CAC; hanning_window[1130] = 16'h7C9C; hanning_window[1131] = 16'h7C8C; hanning_window[1132] = 16'h7C7C; hanning_window[1133] = 16'h7C6B; hanning_window[1134] = 16'h7C5B; hanning_window[1135] = 16'h7C4A; 
    // 索引 1136-1143
    hanning_window[1136] = 16'h7C39; hanning_window[1137] = 16'h7C28; hanning_window[1138] = 16'h7C17; hanning_window[1139] = 16'h7C05; hanning_window[1140] = 16'h7BF4; hanning_window[1141] = 16'h7BE2; hanning_window[1142] = 16'h7BD0; hanning_window[1143] = 16'h7BBE; 
    // 索引 1144-1151
    hanning_window[1144] = 16'h7BAC; hanning_window[1145] = 16'h7B9A; hanning_window[1146] = 16'h7B87; hanning_window[1147] = 16'h7B75; hanning_window[1148] = 16'h7B62; hanning_window[1149] = 16'h7B4F; hanning_window[1150] = 16'h7B3C; hanning_window[1151] = 16'h7B29; 
    // 索引 1152-1159
    hanning_window[1152] = 16'h7B16; hanning_window[1153] = 16'h7B03; hanning_window[1154] = 16'h7AEF; hanning_window[1155] = 16'h7ADB; hanning_window[1156] = 16'h7AC8; hanning_window[1157] = 16'h7AB4; hanning_window[1158] = 16'h7A9F; hanning_window[1159] = 16'h7A8B; 
    // 索引 1160-1167
    hanning_window[1160] = 16'h7A77; hanning_window[1161] = 16'h7A62; hanning_window[1162] = 16'h7A4E; hanning_window[1163] = 16'h7A39; hanning_window[1164] = 16'h7A24; hanning_window[1165] = 16'h7A0F; hanning_window[1166] = 16'h79FA; hanning_window[1167] = 16'h79E4; 
    // 索引 1168-1175
    hanning_window[1168] = 16'h79CF; hanning_window[1169] = 16'h79B9; hanning_window[1170] = 16'h79A3; hanning_window[1171] = 16'h798D; hanning_window[1172] = 16'h7977; hanning_window[1173] = 16'h7961; hanning_window[1174] = 16'h794B; hanning_window[1175] = 16'h7934; 
    // 索引 1176-1183
    hanning_window[1176] = 16'h791E; hanning_window[1177] = 16'h7907; hanning_window[1178] = 16'h78F0; hanning_window[1179] = 16'h78D9; hanning_window[1180] = 16'h78C2; hanning_window[1181] = 16'h78AA; hanning_window[1182] = 16'h7893; hanning_window[1183] = 16'h787B; 
    // 索引 1184-1191
    hanning_window[1184] = 16'h7864; hanning_window[1185] = 16'h784C; hanning_window[1186] = 16'h7834; hanning_window[1187] = 16'h781C; hanning_window[1188] = 16'h7803; hanning_window[1189] = 16'h77EB; hanning_window[1190] = 16'h77D3; hanning_window[1191] = 16'h77BA; 
    // 索引 1192-1199
    hanning_window[1192] = 16'h77A1; hanning_window[1193] = 16'h7788; hanning_window[1194] = 16'h776F; hanning_window[1195] = 16'h7756; hanning_window[1196] = 16'h773D; hanning_window[1197] = 16'h7723; hanning_window[1198] = 16'h7709; hanning_window[1199] = 16'h76F0; 
    // 索引 1200-1207
    hanning_window[1200] = 16'h76D6; hanning_window[1201] = 16'h76BC; hanning_window[1202] = 16'h76A2; hanning_window[1203] = 16'h7687; hanning_window[1204] = 16'h766D; hanning_window[1205] = 16'h7653; hanning_window[1206] = 16'h7638; hanning_window[1207] = 16'h761D; 
    // 索引 1208-1215
    hanning_window[1208] = 16'h7602; hanning_window[1209] = 16'h75E7; hanning_window[1210] = 16'h75CC; hanning_window[1211] = 16'h75B1; hanning_window[1212] = 16'h7595; hanning_window[1213] = 16'h757A; hanning_window[1214] = 16'h755E; hanning_window[1215] = 16'h7542; 
    // 索引 1216-1223
    hanning_window[1216] = 16'h7526; hanning_window[1217] = 16'h750A; hanning_window[1218] = 16'h74EE; hanning_window[1219] = 16'h74D2; hanning_window[1220] = 16'h74B5; hanning_window[1221] = 16'h7499; hanning_window[1222] = 16'h747C; hanning_window[1223] = 16'h745F; 
    // 索引 1224-1231
    hanning_window[1224] = 16'h7442; hanning_window[1225] = 16'h7425; hanning_window[1226] = 16'h7408; hanning_window[1227] = 16'h73EA; hanning_window[1228] = 16'h73CD; hanning_window[1229] = 16'h73AF; hanning_window[1230] = 16'h7392; hanning_window[1231] = 16'h7374; 
    // 索引 1232-1239
    hanning_window[1232] = 16'h7356; hanning_window[1233] = 16'h7338; hanning_window[1234] = 16'h7319; hanning_window[1235] = 16'h72FB; hanning_window[1236] = 16'h72DD; hanning_window[1237] = 16'h72BE; hanning_window[1238] = 16'h729F; hanning_window[1239] = 16'h7280; 
    // 索引 1240-1247
    hanning_window[1240] = 16'h7262; hanning_window[1241] = 16'h7242; hanning_window[1242] = 16'h7223; hanning_window[1243] = 16'h7204; hanning_window[1244] = 16'h71E4; hanning_window[1245] = 16'h71C5; hanning_window[1246] = 16'h71A5; hanning_window[1247] = 16'h7185; 
    // 索引 1248-1255
    hanning_window[1248] = 16'h7166; hanning_window[1249] = 16'h7146; hanning_window[1250] = 16'h7125; hanning_window[1251] = 16'h7105; hanning_window[1252] = 16'h70E5; hanning_window[1253] = 16'h70C4; hanning_window[1254] = 16'h70A4; hanning_window[1255] = 16'h7083; 
    // 索引 1256-1263
    hanning_window[1256] = 16'h7062; hanning_window[1257] = 16'h7041; hanning_window[1258] = 16'h7020; hanning_window[1259] = 16'h6FFF; hanning_window[1260] = 16'h6FDD; hanning_window[1261] = 16'h6FBC; hanning_window[1262] = 16'h6F9A; hanning_window[1263] = 16'h6F79; 
    // 索引 1264-1271
    hanning_window[1264] = 16'h6F57; hanning_window[1265] = 16'h6F35; hanning_window[1266] = 16'h6F13; hanning_window[1267] = 16'h6EF1; hanning_window[1268] = 16'h6ECF; hanning_window[1269] = 16'h6EAC; hanning_window[1270] = 16'h6E8A; hanning_window[1271] = 16'h6E67; 
    // 索引 1272-1279
    hanning_window[1272] = 16'h6E45; hanning_window[1273] = 16'h6E22; hanning_window[1274] = 16'h6DFF; hanning_window[1275] = 16'h6DDC; hanning_window[1276] = 16'h6DB9; hanning_window[1277] = 16'h6D95; hanning_window[1278] = 16'h6D72; hanning_window[1279] = 16'h6D4F; 
    // 索引 1280-1287
    hanning_window[1280] = 16'h6D2B; hanning_window[1281] = 16'h6D07; hanning_window[1282] = 16'h6CE4; hanning_window[1283] = 16'h6CC0; hanning_window[1284] = 16'h6C9C; hanning_window[1285] = 16'h6C77; hanning_window[1286] = 16'h6C53; hanning_window[1287] = 16'h6C2F; 
    // 索引 1288-1295
    hanning_window[1288] = 16'h6C0B; hanning_window[1289] = 16'h6BE6; hanning_window[1290] = 16'h6BC1; hanning_window[1291] = 16'h6B9D; hanning_window[1292] = 16'h6B78; hanning_window[1293] = 16'h6B53; hanning_window[1294] = 16'h6B2E; hanning_window[1295] = 16'h6B08; 
    // 索引 1296-1303
    hanning_window[1296] = 16'h6AE3; hanning_window[1297] = 16'h6ABE; hanning_window[1298] = 16'h6A98; hanning_window[1299] = 16'h6A73; hanning_window[1300] = 16'h6A4D; hanning_window[1301] = 16'h6A27; hanning_window[1302] = 16'h6A01; hanning_window[1303] = 16'h69DB; 
    // 索引 1304-1311
    hanning_window[1304] = 16'h69B5; hanning_window[1305] = 16'h698F; hanning_window[1306] = 16'h6969; hanning_window[1307] = 16'h6942; hanning_window[1308] = 16'h691C; hanning_window[1309] = 16'h68F5; hanning_window[1310] = 16'h68CF; hanning_window[1311] = 16'h68A8; 
    // 索引 1312-1319
    hanning_window[1312] = 16'h6881; hanning_window[1313] = 16'h685A; hanning_window[1314] = 16'h6833; hanning_window[1315] = 16'h680C; hanning_window[1316] = 16'h67E4; hanning_window[1317] = 16'h67BD; hanning_window[1318] = 16'h6796; hanning_window[1319] = 16'h676E; 
    // 索引 1320-1327
    hanning_window[1320] = 16'h6746; hanning_window[1321] = 16'h671F; hanning_window[1322] = 16'h66F7; hanning_window[1323] = 16'h66CF; hanning_window[1324] = 16'h66A7; hanning_window[1325] = 16'h667F; hanning_window[1326] = 16'h6656; hanning_window[1327] = 16'h662E; 
    // 索引 1328-1335
    hanning_window[1328] = 16'h6606; hanning_window[1329] = 16'h65DD; hanning_window[1330] = 16'h65B5; hanning_window[1331] = 16'h658C; hanning_window[1332] = 16'h6563; hanning_window[1333] = 16'h653A; hanning_window[1334] = 16'h6511; hanning_window[1335] = 16'h64E8; 
    // 索引 1336-1343
    hanning_window[1336] = 16'h64BF; hanning_window[1337] = 16'h6496; hanning_window[1338] = 16'h646D; hanning_window[1339] = 16'h6443; hanning_window[1340] = 16'h641A; hanning_window[1341] = 16'h63F0; hanning_window[1342] = 16'h63C7; hanning_window[1343] = 16'h639D; 
    // 索引 1344-1351
    hanning_window[1344] = 16'h6373; hanning_window[1345] = 16'h6349; hanning_window[1346] = 16'h631F; hanning_window[1347] = 16'h62F5; hanning_window[1348] = 16'h62CB; hanning_window[1349] = 16'h62A1; hanning_window[1350] = 16'h6276; hanning_window[1351] = 16'h624C; 
    // 索引 1352-1359
    hanning_window[1352] = 16'h6221; hanning_window[1353] = 16'h61F7; hanning_window[1354] = 16'h61CC; hanning_window[1355] = 16'h61A1; hanning_window[1356] = 16'h6177; hanning_window[1357] = 16'h614C; hanning_window[1358] = 16'h6121; hanning_window[1359] = 16'h60F6; 
    // 索引 1360-1367
    hanning_window[1360] = 16'h60CA; hanning_window[1361] = 16'h609F; hanning_window[1362] = 16'h6074; hanning_window[1363] = 16'h6048; hanning_window[1364] = 16'h601D; hanning_window[1365] = 16'h5FF1; hanning_window[1366] = 16'h5FC6; hanning_window[1367] = 16'h5F9A; 
    // 索引 1368-1375
    hanning_window[1368] = 16'h5F6E; hanning_window[1369] = 16'h5F43; hanning_window[1370] = 16'h5F17; hanning_window[1371] = 16'h5EEB; hanning_window[1372] = 16'h5EBF; hanning_window[1373] = 16'h5E92; hanning_window[1374] = 16'h5E66; hanning_window[1375] = 16'h5E3A; 
    // 索引 1376-1383
    hanning_window[1376] = 16'h5E0E; hanning_window[1377] = 16'h5DE1; hanning_window[1378] = 16'h5DB5; hanning_window[1379] = 16'h5D88; hanning_window[1380] = 16'h5D5B; hanning_window[1381] = 16'h5D2F; hanning_window[1382] = 16'h5D02; hanning_window[1383] = 16'h5CD5; 
    // 索引 1384-1391
    hanning_window[1384] = 16'h5CA8; hanning_window[1385] = 16'h5C7B; hanning_window[1386] = 16'h5C4E; hanning_window[1387] = 16'h5C21; hanning_window[1388] = 16'h5BF4; hanning_window[1389] = 16'h5BC6; hanning_window[1390] = 16'h5B99; hanning_window[1391] = 16'h5B6C; 
    // 索引 1392-1399
    hanning_window[1392] = 16'h5B3E; hanning_window[1393] = 16'h5B11; hanning_window[1394] = 16'h5AE3; hanning_window[1395] = 16'h5AB5; hanning_window[1396] = 16'h5A88; hanning_window[1397] = 16'h5A5A; hanning_window[1398] = 16'h5A2C; hanning_window[1399] = 16'h59FE; 
    // 索引 1400-1407
    hanning_window[1400] = 16'h59D0; hanning_window[1401] = 16'h59A2; hanning_window[1402] = 16'h5974; hanning_window[1403] = 16'h5946; hanning_window[1404] = 16'h5917; hanning_window[1405] = 16'h58E9; hanning_window[1406] = 16'h58BB; hanning_window[1407] = 16'h588C; 
    // 索引 1408-1415
    hanning_window[1408] = 16'h585E; hanning_window[1409] = 16'h582F; hanning_window[1410] = 16'h5801; hanning_window[1411] = 16'h57D2; hanning_window[1412] = 16'h57A3; hanning_window[1413] = 16'h5775; hanning_window[1414] = 16'h5746; hanning_window[1415] = 16'h5717; 
    // 索引 1416-1423
    hanning_window[1416] = 16'h56E8; hanning_window[1417] = 16'h56B9; hanning_window[1418] = 16'h568A; hanning_window[1419] = 16'h565B; hanning_window[1420] = 16'h562C; hanning_window[1421] = 16'h55FD; hanning_window[1422] = 16'h55CD; hanning_window[1423] = 16'h559E; 
    // 索引 1424-1431
    hanning_window[1424] = 16'h556F; hanning_window[1425] = 16'h553F; hanning_window[1426] = 16'h5510; hanning_window[1427] = 16'h54E0; hanning_window[1428] = 16'h54B1; hanning_window[1429] = 16'h5481; hanning_window[1430] = 16'h5451; hanning_window[1431] = 16'h5422; 
    // 索引 1432-1439
    hanning_window[1432] = 16'h53F2; hanning_window[1433] = 16'h53C2; hanning_window[1434] = 16'h5392; hanning_window[1435] = 16'h5362; hanning_window[1436] = 16'h5332; hanning_window[1437] = 16'h5302; hanning_window[1438] = 16'h52D2; hanning_window[1439] = 16'h52A2; 
    // 索引 1440-1447
    hanning_window[1440] = 16'h5272; hanning_window[1441] = 16'h5242; hanning_window[1442] = 16'h5212; hanning_window[1443] = 16'h51E2; hanning_window[1444] = 16'h51B1; hanning_window[1445] = 16'h5181; hanning_window[1446] = 16'h5150; hanning_window[1447] = 16'h5120; 
    // 索引 1448-1455
    hanning_window[1448] = 16'h50F0; hanning_window[1449] = 16'h50BF; hanning_window[1450] = 16'h508E; hanning_window[1451] = 16'h505E; hanning_window[1452] = 16'h502D; hanning_window[1453] = 16'h4FFD; hanning_window[1454] = 16'h4FCC; hanning_window[1455] = 16'h4F9B; 
    // 索引 1456-1463
    hanning_window[1456] = 16'h4F6A; hanning_window[1457] = 16'h4F39; hanning_window[1458] = 16'h4F09; hanning_window[1459] = 16'h4ED8; hanning_window[1460] = 16'h4EA7; hanning_window[1461] = 16'h4E76; hanning_window[1462] = 16'h4E45; hanning_window[1463] = 16'h4E14; 
    // 索引 1464-1471
    hanning_window[1464] = 16'h4DE3; hanning_window[1465] = 16'h4DB2; hanning_window[1466] = 16'h4D80; hanning_window[1467] = 16'h4D4F; hanning_window[1468] = 16'h4D1E; hanning_window[1469] = 16'h4CED; hanning_window[1470] = 16'h4CBC; hanning_window[1471] = 16'h4C8A; 
    // 索引 1472-1479
    hanning_window[1472] = 16'h4C59; hanning_window[1473] = 16'h4C28; hanning_window[1474] = 16'h4BF6; hanning_window[1475] = 16'h4BC5; hanning_window[1476] = 16'h4B93; hanning_window[1477] = 16'h4B62; hanning_window[1478] = 16'h4B30; hanning_window[1479] = 16'h4AFF; 
    // 索引 1480-1487
    hanning_window[1480] = 16'h4ACD; hanning_window[1481] = 16'h4A9C; hanning_window[1482] = 16'h4A6A; hanning_window[1483] = 16'h4A38; hanning_window[1484] = 16'h4A07; hanning_window[1485] = 16'h49D5; hanning_window[1486] = 16'h49A3; hanning_window[1487] = 16'h4972; 
    // 索引 1488-1495
    hanning_window[1488] = 16'h4940; hanning_window[1489] = 16'h490E; hanning_window[1490] = 16'h48DC; hanning_window[1491] = 16'h48AA; hanning_window[1492] = 16'h4879; hanning_window[1493] = 16'h4847; hanning_window[1494] = 16'h4815; hanning_window[1495] = 16'h47E3; 
    // 索引 1496-1503
    hanning_window[1496] = 16'h47B1; hanning_window[1497] = 16'h477F; hanning_window[1498] = 16'h474D; hanning_window[1499] = 16'h471B; hanning_window[1500] = 16'h46E9; hanning_window[1501] = 16'h46B7; hanning_window[1502] = 16'h4685; hanning_window[1503] = 16'h4653; 
    // 索引 1504-1511
    hanning_window[1504] = 16'h4621; hanning_window[1505] = 16'h45EF; hanning_window[1506] = 16'h45BD; hanning_window[1507] = 16'h458B; hanning_window[1508] = 16'h4559; hanning_window[1509] = 16'h4527; hanning_window[1510] = 16'h44F5; hanning_window[1511] = 16'h44C2; 
    // 索引 1512-1519
    hanning_window[1512] = 16'h4490; hanning_window[1513] = 16'h445E; hanning_window[1514] = 16'h442C; hanning_window[1515] = 16'h43FA; hanning_window[1516] = 16'h43C8; hanning_window[1517] = 16'h4395; hanning_window[1518] = 16'h4363; hanning_window[1519] = 16'h4331; 
    // 索引 1520-1527
    hanning_window[1520] = 16'h42FF; hanning_window[1521] = 16'h42CC; hanning_window[1522] = 16'h429A; hanning_window[1523] = 16'h4268; hanning_window[1524] = 16'h4236; hanning_window[1525] = 16'h4203; hanning_window[1526] = 16'h41D1; hanning_window[1527] = 16'h419F; 
    // 索引 1528-1535
    hanning_window[1528] = 16'h416D; hanning_window[1529] = 16'h413A; hanning_window[1530] = 16'h4108; hanning_window[1531] = 16'h40D6; hanning_window[1532] = 16'h40A3; hanning_window[1533] = 16'h4071; hanning_window[1534] = 16'h403F; hanning_window[1535] = 16'h400D; 
    // 索引 1536-1543
    hanning_window[1536] = 16'h3FDA; hanning_window[1537] = 16'h3FA8; hanning_window[1538] = 16'h3F76; hanning_window[1539] = 16'h3F43; hanning_window[1540] = 16'h3F11; hanning_window[1541] = 16'h3EDF; hanning_window[1542] = 16'h3EAD; hanning_window[1543] = 16'h3E7A; 
    // 索引 1544-1551
    hanning_window[1544] = 16'h3E48; hanning_window[1545] = 16'h3E16; hanning_window[1546] = 16'h3DE3; hanning_window[1547] = 16'h3DB1; hanning_window[1548] = 16'h3D7F; hanning_window[1549] = 16'h3D4D; hanning_window[1550] = 16'h3D1A; hanning_window[1551] = 16'h3CE8; 
    // 索引 1552-1559
    hanning_window[1552] = 16'h3CB6; hanning_window[1553] = 16'h3C84; hanning_window[1554] = 16'h3C52; hanning_window[1555] = 16'h3C1F; hanning_window[1556] = 16'h3BED; hanning_window[1557] = 16'h3BBB; hanning_window[1558] = 16'h3B89; hanning_window[1559] = 16'h3B57; 
    // 索引 1560-1567
    hanning_window[1560] = 16'h3B25; hanning_window[1561] = 16'h3AF2; hanning_window[1562] = 16'h3AC0; hanning_window[1563] = 16'h3A8E; hanning_window[1564] = 16'h3A5C; hanning_window[1565] = 16'h3A2A; hanning_window[1566] = 16'h39F8; hanning_window[1567] = 16'h39C6; 
    // 索引 1568-1575
    hanning_window[1568] = 16'h3994; hanning_window[1569] = 16'h3962; hanning_window[1570] = 16'h3930; hanning_window[1571] = 16'h38FE; hanning_window[1572] = 16'h38CC; hanning_window[1573] = 16'h389A; hanning_window[1574] = 16'h3868; hanning_window[1575] = 16'h3836; 
    // 索引 1576-1583
    hanning_window[1576] = 16'h3804; hanning_window[1577] = 16'h37D2; hanning_window[1578] = 16'h37A0; hanning_window[1579] = 16'h376E; hanning_window[1580] = 16'h373D; hanning_window[1581] = 16'h370B; hanning_window[1582] = 16'h36D9; hanning_window[1583] = 16'h36A7; 
    // 索引 1584-1591
    hanning_window[1584] = 16'h3675; hanning_window[1585] = 16'h3644; hanning_window[1586] = 16'h3612; hanning_window[1587] = 16'h35E0; hanning_window[1588] = 16'h35AF; hanning_window[1589] = 16'h357D; hanning_window[1590] = 16'h354C; hanning_window[1591] = 16'h351A; 
    // 索引 1592-1599
    hanning_window[1592] = 16'h34E8; hanning_window[1593] = 16'h34B7; hanning_window[1594] = 16'h3485; hanning_window[1595] = 16'h3454; hanning_window[1596] = 16'h3423; hanning_window[1597] = 16'h33F1; hanning_window[1598] = 16'h33C0; hanning_window[1599] = 16'h338E; 
    // 索引 1600-1607
    hanning_window[1600] = 16'h335D; hanning_window[1601] = 16'h332C; hanning_window[1602] = 16'h32FB; hanning_window[1603] = 16'h32C9; hanning_window[1604] = 16'h3298; hanning_window[1605] = 16'h3267; hanning_window[1606] = 16'h3236; hanning_window[1607] = 16'h3205; 
    // 索引 1608-1615
    hanning_window[1608] = 16'h31D4; hanning_window[1609] = 16'h31A3; hanning_window[1610] = 16'h3172; hanning_window[1611] = 16'h3141; hanning_window[1612] = 16'h3110; hanning_window[1613] = 16'h30DF; hanning_window[1614] = 16'h30AE; hanning_window[1615] = 16'h307D; 
    // 索引 1616-1623
    hanning_window[1616] = 16'h304D; hanning_window[1617] = 16'h301C; hanning_window[1618] = 16'h2FEB; hanning_window[1619] = 16'h2FBA; hanning_window[1620] = 16'h2F8A; hanning_window[1621] = 16'h2F59; hanning_window[1622] = 16'h2F29; hanning_window[1623] = 16'h2EF8; 
    // 索引 1624-1631
    hanning_window[1624] = 16'h2EC8; hanning_window[1625] = 16'h2E97; hanning_window[1626] = 16'h2E67; hanning_window[1627] = 16'h2E37; hanning_window[1628] = 16'h2E06; hanning_window[1629] = 16'h2DD6; hanning_window[1630] = 16'h2DA6; hanning_window[1631] = 16'h2D76; 
    // 索引 1632-1639
    hanning_window[1632] = 16'h2D46; hanning_window[1633] = 16'h2D16; hanning_window[1634] = 16'h2CE6; hanning_window[1635] = 16'h2CB6; hanning_window[1636] = 16'h2C86; hanning_window[1637] = 16'h2C56; hanning_window[1638] = 16'h2C26; hanning_window[1639] = 16'h2BF6; 
    // 索引 1640-1647
    hanning_window[1640] = 16'h2BC6; hanning_window[1641] = 16'h2B97; hanning_window[1642] = 16'h2B67; hanning_window[1643] = 16'h2B37; hanning_window[1644] = 16'h2B08; hanning_window[1645] = 16'h2AD8; hanning_window[1646] = 16'h2AA9; hanning_window[1647] = 16'h2A7A; 
    // 索引 1648-1655
    hanning_window[1648] = 16'h2A4A; hanning_window[1649] = 16'h2A1B; hanning_window[1650] = 16'h29EC; hanning_window[1651] = 16'h29BD; hanning_window[1652] = 16'h298E; hanning_window[1653] = 16'h295E; hanning_window[1654] = 16'h292F; hanning_window[1655] = 16'h2900; 
    // 索引 1656-1663
    hanning_window[1656] = 16'h28D2; hanning_window[1657] = 16'h28A3; hanning_window[1658] = 16'h2874; hanning_window[1659] = 16'h2845; hanning_window[1660] = 16'h2817; hanning_window[1661] = 16'h27E8; hanning_window[1662] = 16'h27B9; hanning_window[1663] = 16'h278B; 
    // 索引 1664-1671
    hanning_window[1664] = 16'h275C; hanning_window[1665] = 16'h272E; hanning_window[1666] = 16'h2700; hanning_window[1667] = 16'h26D1; hanning_window[1668] = 16'h26A3; hanning_window[1669] = 16'h2675; hanning_window[1670] = 16'h2647; hanning_window[1671] = 16'h2619; 
    // 索引 1672-1679
    hanning_window[1672] = 16'h25EB; hanning_window[1673] = 16'h25BD; hanning_window[1674] = 16'h258F; hanning_window[1675] = 16'h2562; hanning_window[1676] = 16'h2534; hanning_window[1677] = 16'h2506; hanning_window[1678] = 16'h24D9; hanning_window[1679] = 16'h24AB; 
    // 索引 1680-1687
    hanning_window[1680] = 16'h247E; hanning_window[1681] = 16'h2450; hanning_window[1682] = 16'h2423; hanning_window[1683] = 16'h23F6; hanning_window[1684] = 16'h23C9; hanning_window[1685] = 16'h239B; hanning_window[1686] = 16'h236E; hanning_window[1687] = 16'h2341; 
    // 索引 1688-1695
    hanning_window[1688] = 16'h2315; hanning_window[1689] = 16'h22E8; hanning_window[1690] = 16'h22BB; hanning_window[1691] = 16'h228E; hanning_window[1692] = 16'h2262; hanning_window[1693] = 16'h2235; hanning_window[1694] = 16'h2209; hanning_window[1695] = 16'h21DC; 
    // 索引 1696-1703
    hanning_window[1696] = 16'h21B0; hanning_window[1697] = 16'h2184; hanning_window[1698] = 16'h2157; hanning_window[1699] = 16'h212B; hanning_window[1700] = 16'h20FF; hanning_window[1701] = 16'h20D3; hanning_window[1702] = 16'h20A8; hanning_window[1703] = 16'h207C; 
    // 索引 1704-1711
    hanning_window[1704] = 16'h2050; hanning_window[1705] = 16'h2024; hanning_window[1706] = 16'h1FF9; hanning_window[1707] = 16'h1FCD; hanning_window[1708] = 16'h1FA2; hanning_window[1709] = 16'h1F76; hanning_window[1710] = 16'h1F4B; hanning_window[1711] = 16'h1F20; 
    // 索引 1712-1719
    hanning_window[1712] = 16'h1EF5; hanning_window[1713] = 16'h1ECA; hanning_window[1714] = 16'h1E9F; hanning_window[1715] = 16'h1E74; hanning_window[1716] = 16'h1E49; hanning_window[1717] = 16'h1E1F; hanning_window[1718] = 16'h1DF4; hanning_window[1719] = 16'h1DC9; 
    // 索引 1720-1727
    hanning_window[1720] = 16'h1D9F; hanning_window[1721] = 16'h1D75; hanning_window[1722] = 16'h1D4A; hanning_window[1723] = 16'h1D20; hanning_window[1724] = 16'h1CF6; hanning_window[1725] = 16'h1CCC; hanning_window[1726] = 16'h1CA2; hanning_window[1727] = 16'h1C78; 
    // 索引 1728-1735
    hanning_window[1728] = 16'h1C4E; hanning_window[1729] = 16'h1C25; hanning_window[1730] = 16'h1BFB; hanning_window[1731] = 16'h1BD1; hanning_window[1732] = 16'h1BA8; hanning_window[1733] = 16'h1B7F; hanning_window[1734] = 16'h1B55; hanning_window[1735] = 16'h1B2C; 
    // 索引 1736-1743
    hanning_window[1736] = 16'h1B03; hanning_window[1737] = 16'h1ADA; hanning_window[1738] = 16'h1AB1; hanning_window[1739] = 16'h1A88; hanning_window[1740] = 16'h1A60; hanning_window[1741] = 16'h1A37; hanning_window[1742] = 16'h1A0F; hanning_window[1743] = 16'h19E6; 
    // 索引 1744-1751
    hanning_window[1744] = 16'h19BE; hanning_window[1745] = 16'h1995; hanning_window[1746] = 16'h196D; hanning_window[1747] = 16'h1945; hanning_window[1748] = 16'h191D; hanning_window[1749] = 16'h18F5; hanning_window[1750] = 16'h18CD; hanning_window[1751] = 16'h18A6; 
    // 索引 1752-1759
    hanning_window[1752] = 16'h187E; hanning_window[1753] = 16'h1857; hanning_window[1754] = 16'h182F; hanning_window[1755] = 16'h1808; hanning_window[1756] = 16'h17E1; hanning_window[1757] = 16'h17BA; hanning_window[1758] = 16'h1793; hanning_window[1759] = 16'h176C; 
    // 索引 1760-1767
    hanning_window[1760] = 16'h1745; hanning_window[1761] = 16'h171E; hanning_window[1762] = 16'h16F7; hanning_window[1763] = 16'h16D1; hanning_window[1764] = 16'h16AA; hanning_window[1765] = 16'h1684; hanning_window[1766] = 16'h165E; hanning_window[1767] = 16'h1638; 
    // 索引 1768-1775
    hanning_window[1768] = 16'h1612; hanning_window[1769] = 16'h15EC; hanning_window[1770] = 16'h15C6; hanning_window[1771] = 16'h15A0; hanning_window[1772] = 16'h157A; hanning_window[1773] = 16'h1555; hanning_window[1774] = 16'h152F; hanning_window[1775] = 16'h150A; 
    // 索引 1776-1783
    hanning_window[1776] = 16'h14E5; hanning_window[1777] = 16'h14C0; hanning_window[1778] = 16'h149B; hanning_window[1779] = 16'h1476; hanning_window[1780] = 16'h1451; hanning_window[1781] = 16'h142C; hanning_window[1782] = 16'h1408; hanning_window[1783] = 16'h13E3; 
    // 索引 1784-1791
    hanning_window[1784] = 16'h13BF; hanning_window[1785] = 16'h139B; hanning_window[1786] = 16'h1376; hanning_window[1787] = 16'h1352; hanning_window[1788] = 16'h132E; hanning_window[1789] = 16'h130B; hanning_window[1790] = 16'h12E7; hanning_window[1791] = 16'h12C3; 
    // 索引 1792-1799
    hanning_window[1792] = 16'h12A0; hanning_window[1793] = 16'h127C; hanning_window[1794] = 16'h1259; hanning_window[1795] = 16'h1236; hanning_window[1796] = 16'h1213; hanning_window[1797] = 16'h11F0; hanning_window[1798] = 16'h11CD; hanning_window[1799] = 16'h11AA; 
    // 索引 1800-1807
    hanning_window[1800] = 16'h1188; hanning_window[1801] = 16'h1165; hanning_window[1802] = 16'h1143; hanning_window[1803] = 16'h1120; hanning_window[1804] = 16'h10FE; hanning_window[1805] = 16'h10DC; hanning_window[1806] = 16'h10BA; hanning_window[1807] = 16'h1098; 
    // 索引 1808-1815
    hanning_window[1808] = 16'h1076; hanning_window[1809] = 16'h1055; hanning_window[1810] = 16'h1033; hanning_window[1811] = 16'h1012; hanning_window[1812] = 16'h0FF1; hanning_window[1813] = 16'h0FD0; hanning_window[1814] = 16'h0FAF; hanning_window[1815] = 16'h0F8E; 
    // 索引 1816-1823
    hanning_window[1816] = 16'h0F6D; hanning_window[1817] = 16'h0F4C; hanning_window[1818] = 16'h0F2C; hanning_window[1819] = 16'h0F0B; hanning_window[1820] = 16'h0EEB; hanning_window[1821] = 16'h0ECB; hanning_window[1822] = 16'h0EAA; hanning_window[1823] = 16'h0E8A; 
    // 索引 1824-1831
    hanning_window[1824] = 16'h0E6B; hanning_window[1825] = 16'h0E4B; hanning_window[1826] = 16'h0E2B; hanning_window[1827] = 16'h0E0C; hanning_window[1828] = 16'h0DEC; hanning_window[1829] = 16'h0DCD; hanning_window[1830] = 16'h0DAE; hanning_window[1831] = 16'h0D8F; 
    // 索引 1832-1839
    hanning_window[1832] = 16'h0D70; hanning_window[1833] = 16'h0D51; hanning_window[1834] = 16'h0D33; hanning_window[1835] = 16'h0D14; hanning_window[1836] = 16'h0CF6; hanning_window[1837] = 16'h0CD7; hanning_window[1838] = 16'h0CB9; hanning_window[1839] = 16'h0C9B; 
    // 索引 1840-1847
    hanning_window[1840] = 16'h0C7D; hanning_window[1841] = 16'h0C60; hanning_window[1842] = 16'h0C42; hanning_window[1843] = 16'h0C24; hanning_window[1844] = 16'h0C07; hanning_window[1845] = 16'h0BEA; hanning_window[1846] = 16'h0BCD; hanning_window[1847] = 16'h0BB0; 
    // 索引 1848-1855
    hanning_window[1848] = 16'h0B93; hanning_window[1849] = 16'h0B76; hanning_window[1850] = 16'h0B59; hanning_window[1851] = 16'h0B3D; hanning_window[1852] = 16'h0B20; hanning_window[1853] = 16'h0B04; hanning_window[1854] = 16'h0AE8; hanning_window[1855] = 16'h0ACC; 
    // 索引 1856-1863
    hanning_window[1856] = 16'h0AB0; hanning_window[1857] = 16'h0A94; hanning_window[1858] = 16'h0A79; hanning_window[1859] = 16'h0A5D; hanning_window[1860] = 16'h0A42; hanning_window[1861] = 16'h0A26; hanning_window[1862] = 16'h0A0B; hanning_window[1863] = 16'h09F0; 
    // 索引 1864-1871
    hanning_window[1864] = 16'h09D5; hanning_window[1865] = 16'h09BB; hanning_window[1866] = 16'h09A0; hanning_window[1867] = 16'h0986; hanning_window[1868] = 16'h096B; hanning_window[1869] = 16'h0951; hanning_window[1870] = 16'h0937; hanning_window[1871] = 16'h091D; 
    // 索引 1872-1879
    hanning_window[1872] = 16'h0903; hanning_window[1873] = 16'h08EA; hanning_window[1874] = 16'h08D0; hanning_window[1875] = 16'h08B7; hanning_window[1876] = 16'h089E; hanning_window[1877] = 16'h0884; hanning_window[1878] = 16'h086B; hanning_window[1879] = 16'h0853; 
    // 索引 1880-1887
    hanning_window[1880] = 16'h083A; hanning_window[1881] = 16'h0821; hanning_window[1882] = 16'h0809; hanning_window[1883] = 16'h07F0; hanning_window[1884] = 16'h07D8; hanning_window[1885] = 16'h07C0; hanning_window[1886] = 16'h07A8; hanning_window[1887] = 16'h0790; 
    // 索引 1888-1895
    hanning_window[1888] = 16'h0779; hanning_window[1889] = 16'h0761; hanning_window[1890] = 16'h074A; hanning_window[1891] = 16'h0733; hanning_window[1892] = 16'h071C; hanning_window[1893] = 16'h0705; hanning_window[1894] = 16'h06EE; hanning_window[1895] = 16'h06D7; 
    // 索引 1896-1903
    hanning_window[1896] = 16'h06C1; hanning_window[1897] = 16'h06AA; hanning_window[1898] = 16'h0694; hanning_window[1899] = 16'h067E; hanning_window[1900] = 16'h0668; hanning_window[1901] = 16'h0652; hanning_window[1902] = 16'h063C; hanning_window[1903] = 16'h0627; 
    // 索引 1904-1911
    hanning_window[1904] = 16'h0611; hanning_window[1905] = 16'h05FC; hanning_window[1906] = 16'h05E7; hanning_window[1907] = 16'h05D2; hanning_window[1908] = 16'h05BD; hanning_window[1909] = 16'h05A8; hanning_window[1910] = 16'h0593; hanning_window[1911] = 16'h057F; 
    // 索引 1912-1919
    hanning_window[1912] = 16'h056B; hanning_window[1913] = 16'h0556; hanning_window[1914] = 16'h0542; hanning_window[1915] = 16'h052F; hanning_window[1916] = 16'h051B; hanning_window[1917] = 16'h0507; hanning_window[1918] = 16'h04F4; hanning_window[1919] = 16'h04E0; 
    // 索引 1920-1927
    hanning_window[1920] = 16'h04CD; hanning_window[1921] = 16'h04BA; hanning_window[1922] = 16'h04A7; hanning_window[1923] = 16'h0494; hanning_window[1924] = 16'h0482; hanning_window[1925] = 16'h046F; hanning_window[1926] = 16'h045D; hanning_window[1927] = 16'h044B; 
    // 索引 1928-1935
    hanning_window[1928] = 16'h0439; hanning_window[1929] = 16'h0427; hanning_window[1930] = 16'h0415; hanning_window[1931] = 16'h0404; hanning_window[1932] = 16'h03F2; hanning_window[1933] = 16'h03E1; hanning_window[1934] = 16'h03D0; hanning_window[1935] = 16'h03BF; 
    // 索引 1936-1943
    hanning_window[1936] = 16'h03AE; hanning_window[1937] = 16'h039D; hanning_window[1938] = 16'h038C; hanning_window[1939] = 16'h037C; hanning_window[1940] = 16'h036C; hanning_window[1941] = 16'h035C; hanning_window[1942] = 16'h034C; hanning_window[1943] = 16'h033C; 
    // 索引 1944-1951
    hanning_window[1944] = 16'h032C; hanning_window[1945] = 16'h031C; hanning_window[1946] = 16'h030D; hanning_window[1947] = 16'h02FE; hanning_window[1948] = 16'h02EF; hanning_window[1949] = 16'h02E0; hanning_window[1950] = 16'h02D1; hanning_window[1951] = 16'h02C2; 
    // 索引 1952-1959
    hanning_window[1952] = 16'h02B4; hanning_window[1953] = 16'h02A5; hanning_window[1954] = 16'h0297; hanning_window[1955] = 16'h0289; hanning_window[1956] = 16'h027B; hanning_window[1957] = 16'h026D; hanning_window[1958] = 16'h0260; hanning_window[1959] = 16'h0252; 
    // 索引 1960-1967
    hanning_window[1960] = 16'h0245; hanning_window[1961] = 16'h0238; hanning_window[1962] = 16'h022A; hanning_window[1963] = 16'h021E; hanning_window[1964] = 16'h0211; hanning_window[1965] = 16'h0204; hanning_window[1966] = 16'h01F8; hanning_window[1967] = 16'h01EB; 
    // 索引 1968-1975
    hanning_window[1968] = 16'h01DF; hanning_window[1969] = 16'h01D3; hanning_window[1970] = 16'h01C7; hanning_window[1971] = 16'h01BC; hanning_window[1972] = 16'h01B0; hanning_window[1973] = 16'h01A5; hanning_window[1974] = 16'h019A; hanning_window[1975] = 16'h018E; 
    // 索引 1976-1983
    hanning_window[1976] = 16'h0184; hanning_window[1977] = 16'h0179; hanning_window[1978] = 16'h016E; hanning_window[1979] = 16'h0164; hanning_window[1980] = 16'h0159; hanning_window[1981] = 16'h014F; hanning_window[1982] = 16'h0145; hanning_window[1983] = 16'h013B; 
    // 索引 1984-1991
    hanning_window[1984] = 16'h0131; hanning_window[1985] = 16'h0128; hanning_window[1986] = 16'h011E; hanning_window[1987] = 16'h0115; hanning_window[1988] = 16'h010C; hanning_window[1989] = 16'h0103; hanning_window[1990] = 16'h00FA; hanning_window[1991] = 16'h00F1; 
    // 索引 1992-1999
    hanning_window[1992] = 16'h00E9; hanning_window[1993] = 16'h00E1; hanning_window[1994] = 16'h00D8; hanning_window[1995] = 16'h00D0; hanning_window[1996] = 16'h00C8; hanning_window[1997] = 16'h00C1; hanning_window[1998] = 16'h00B9; hanning_window[1999] = 16'h00B2; 
    // 索引 2000-2007
    hanning_window[2000] = 16'h00AA; hanning_window[2001] = 16'h00A3; hanning_window[2002] = 16'h009C; hanning_window[2003] = 16'h0095; hanning_window[2004] = 16'h008F; hanning_window[2005] = 16'h0088; hanning_window[2006] = 16'h0082; hanning_window[2007] = 16'h007B; 
    // 索引 2008-2015
    hanning_window[2008] = 16'h0075; hanning_window[2009] = 16'h006F; hanning_window[2010] = 16'h006A; hanning_window[2011] = 16'h0064; hanning_window[2012] = 16'h005E; hanning_window[2013] = 16'h0059; hanning_window[2014] = 16'h0054; hanning_window[2015] = 16'h004F; 
    // 索引 2016-2023
    hanning_window[2016] = 16'h004A; hanning_window[2017] = 16'h0045; hanning_window[2018] = 16'h0041; hanning_window[2019] = 16'h003C; hanning_window[2020] = 16'h0038; hanning_window[2021] = 16'h0034; hanning_window[2022] = 16'h0030; hanning_window[2023] = 16'h002C; 
    // 索引 2024-2031
    hanning_window[2024] = 16'h0029; hanning_window[2025] = 16'h0025; hanning_window[2026] = 16'h0022; hanning_window[2027] = 16'h001F; hanning_window[2028] = 16'h001C; hanning_window[2029] = 16'h0019; hanning_window[2030] = 16'h0016; hanning_window[2031] = 16'h0014; 
    // 索引 2032-2039
    hanning_window[2032] = 16'h0011; hanning_window[2033] = 16'h000F; hanning_window[2034] = 16'h000D; hanning_window[2035] = 16'h000B; hanning_window[2036] = 16'h0009; hanning_window[2037] = 16'h0008; hanning_window[2038] = 16'h0006; hanning_window[2039] = 16'h0005; 
    // 索引 2040-2047
    hanning_window[2040] = 16'h0004; hanning_window[2041] = 16'h0003; hanning_window[2042] = 16'h0002; hanning_window[2043] = 16'h0001; hanning_window[2044] = 16'h0001; hanning_window[2045] = 16'h0000; hanning_window[2046] = 16'h0000; hanning_window[2047] = 16'h0000; 
end

// 窗函数应用中间信号
reg [31:0] windowed_value;

// Sample buffer management with window function application
always @(posedge adc_clk or negedge rst_n) begin
    if (!rst_n) begin
        write_ptr <= 0;
        data_valid <= 1'b0;
        for (i = 0; i < BUFFER_DEPTH; i = i + 1) begin
            sample_buffer[i] <= 16'd0;
        end
    end else begin
        // 应用汉宁窗 - 将ADC数据与相应位置的窗函数系数相乘
        windowed_value = $signed(adc_data) * $signed(hanning_window[write_ptr]);
        
        // 存储加窗后的采样数据 (取乘积的高16位，相当于右移15位)
        sample_buffer[write_ptr] <= windowed_value[30:15];
        
        // 更新写指针
        write_ptr <= (write_ptr + 1) % BUFFER_DEPTH;
        data_valid <= 1'b1;  // Set valid after first sample
    end
end

// Data output
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_out <= 16'd0;
    end else if (data_valid) begin
        data_out <= sample_buffer[write_ptr];
    end
end

endmodule