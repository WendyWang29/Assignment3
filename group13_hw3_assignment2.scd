
/*
TO EXECUTE THE PROGRAM:
1) boot the server;
2) run the first SynthDef block
2) run the second SynthDef block
3) run the program block
*/


s.boot;

// FIRST SYNTHDEF /////////////////////////
(
SynthDef(\risset, {
	| out= 0, pan= 0, freq= 400, amp= 0.2, dur= 2, t_trig=1, del=0.3,
	room=0.5, mix=0.33, t=8|
	var amps= [1, 0.67, 1, 1.8, 2.67, 1.67, 1.46, 1.33, 1.33, 1, 1.33];
	var durs= [1, 0.9, 0.65, 0.55, 0.325, 0.35, 0.25, 0.2, 0.15, 0.1, 0.075];

	var frqs= [0.56, 0.56, 0.92, 0.92, 1.19, 1.7, 2, 2.74, 3, 3.76, 4.07];
	var dets= [0, 1, 0, 1.7, 0, 0, 0, 0, 0, 0, 0];    // Detune

	var src= Mix.fill(11, {
		arg i;
		var env = EnvGen.ar(Env.perc(0.005, dur*durs[i], amps[i], -4.5), t_trig);
		SinOsc.ar(freq*frqs[i]+dets[i], 0, amp*env);
	});

	Out.ar(out, FreeVerb.ar(
		in:(Pan2.ar(Linen.kr( Impulse.kr(0),attackTime:0.005, releaseTime:t, doneAction:Done.freeSelf)*src, pan)),
		mix:mix,
		room:room,
	));
}).add;
)

//a= Synth(\risset);    //for testing the synth


//SECOND SYNTHDEF ////////////////////////////////

(
SynthDef(\reverb_bell,{ arg out = 0, f = 1, ampl = 0.1, dur = 1, det = 0, freq = 500, g=1, reverbGain = 0.2, pan=0.5;
	var predelay, earlyRef, input, lateRef,outsig,singleosc = {|ff,aa,dr,dt|
		OffsetOut.ar(1, SinOsc.ar(freq:freq*ff + dt, mul:ampl)*EnvGen.kr(Env.perc(attackTime: 0.01, releaseTime: 2*dr, level: aa*0.1, curve: -4.0),doneAction:0));};

	singleosc.(1, 1, 0.56, 0);
	singleosc.(0.67, 0.9, 0.56, 1);
	singleosc.(1, 0.65, 0.92, 0);
	singleosc.(1.8, 0.55, 0.92, 1.7);
	singleosc.(2.67, 0.325, 1.19, 0);
	singleosc.(1.67, 0.35, 1.7, 0);
	singleosc.(1.46, 0.25, 2, 0);
	singleosc.(1.33, 0.2, 2.74, 0);
	singleosc.(1.33, 0.15, 3, 0);
	singleosc.(1, 0.1, 3.76, 0);
	singleosc.(1.33, 0.075, 4.07, 0);

	input = In.ar(1, 1);
	predelay = DelayN.ar(input, 0.048);
	earlyRef = Mix.fill(7, {CombL.ar(predelay, 0.1, LFNoise1.kr(0.1.rand, 0.04, 0.05), 3)});
	reverbGain = (0.2)*g;

	lateRef = earlyRef;
	4.do({lateRef = AllpassN.ar(lateRef, 0.050, [0.050.rand, 0.050.rand], 0.7)});
	outsig = Linen.kr(Impulse.kr(0),0,dur,doneAction:Done.freeSelf)*(input + (reverbGain * lateRef));
	Out.ar(out, Pan2.ar(outsig,pan));
}).add;
)

m = Synth(\reverb_bell);



// PROGRAM BLOCK /////////////////////////////////////////////
(
(

MIDIClient.init;
MIDIIn.connectAll;

w=Window.new("MAE Wizz-bell",
	Rect.new(
	left: Window.screenBounds.width/2-280,
	top: Window.screenBounds.height/2-100,
	width:560,
	height:180
),
resizable:false))
.front
.alwaysOnTop_(true)
.view.background_(Color(0.20, 0.36, 0.45))
.onClose_({CmdPeriod.run;});


//LABELS below the buttons ////////////////////////////////

StaticText(w, Rect(left:20, top:52, width:160, height:30))
.string_("Gyroscope controlled")
.align_(\center)
.font_(Font("Arial", size:12, italic:true))
.stringColor_(Color.white);

StaticText(w, Rect(left:200, top:52, width:160, height:30))
.string_("Accelerometer controlled")
.align_(\center)
.font_(Font("Arial", size:12, italic:true))
.stringColor_(Color.white);

StaticText(w, Rect(left:380, top:52, width:160, height:30))
.string_("Compass controlled")
.align_(\center)
.font_(Font("Arial", size:12, italic:true))
.stringColor_(Color.white);

StaticText(w, Rect(left:220, top:90, width:120, height:50))
.string_("🧙‍")
.align_(\center)
.font_(Font("Arial", size:40))
.stringColor_(Color.white);

StaticText(w, Rect(left:220, top:130, width:120, height:50))
.string_("MAE WIZZ-BELL")
.align_(\center)
.font_(Font("Arial", size:12, bold:false))
.stringColor_(Color.white);


///////////////////////////////////////////////////////////


~buttonBell = Button(w, Rect(left:20, top:20, width:160, height:30))
.font_(Font("Arial", size:14, bold:true))
.states_([
	["PLAY THE BELLS", Color.white, Color(0.71, 0.62, 0.26)],
	["OFF", Color.white, Color(0.71, 0.71, 0.71)] ])
.action_({
	arg obj;
	if (obj.value==1,
		{
			//Button's function starts here
			var keys;
			var p;   //global variable that will store the pan value
			var a;   //global variable that will store the amp value

			keys=Array.newClear(128);

			~noteOnFunc = {
				arg val, num, chan, src;
				var node;
				node = keys.at(num);

				if (node.notNil, {
					n.release;
					keys.put(num, nil);
				});

				//gyrOSC /////////////////////////////////////////////
				OSCdef.new(\panValue,{
					arg msg, time, addr, port;
					p = msg[2].linlin(-1.57, 1.57, -1,1);   //rollio, roll
				},
				'/gyrosc/gyro');

				OSCdef.new(\ampValue,{
					arg msg, time, addr, port;
					h = msg[1].linlin(-1.57, 1.57, 400,2500);   //beccheggio, pitch
					h.postln;
				},
				'/gyrosc/gyro');

				//////////////////////////////////////////////////////

				node=Synth.tail(nil, \risset, [\freq, num.midicps, \amp, val/h, \pan, p]);
				keys.put(num, node);
				[num, val].postln;
			};

			a=MIDIFunc.noteOn(func:~noteOnFunc);

			~noteOffFunc = {
				arg val, num, chan, src;
				var node;
				node = keys.at(num);
				if (node.notNil, {
					node.set(\gate, 0);
					node.release;
					keys.put(num, nil);
				});
			};

			b=MIDIFunc.noteOff(func:~noteOffFunc);

		},
		{
			CmdPeriod.run;

		};
		///// button's function ends here
)});


~buttonHitTheBell = Button(w, Rect(left:200, top:20, width:160, height:30))
.font_(Font("Arial", size:14, bold:true))
.states_([
	["HIT THE BELL", Color.white, Color(0.71, 0.62, 0.26)],
	["OFF", Color.white, Color(0.71, 0.71, 0.71)] ])
.action_({
	arg obj;
	if (obj.value==1,{
		OSCdef.new(\playTheBell,
			{
				arg msg, time, addr, port;
				a=(msg[1]+msg[2]+msg[3]).postln;   //accellerometro
				if (a>1.5,
					{
						Synth(\reverb_bell);
				})
			},
			'/gyrosc/accel');
	}, {CmdPeriod.run;});
});

~buttonFollow = Button(w, Rect(left:380, top:20, width:160, height:30))
.font_(Font("Arial", size:14, bold:true))
.states_([
	["FOLLOW THE BELLS", Color.white, Color(0.71, 0.62, 0.26)],
	["OFF", Color.white, Color(0.71, 0.71, 0.71)] ])
.action_({
	arg obj;
	if (obj.value==1,{

		OSCdef.new(\bussola,
			{
				arg msg, time, addr, port;
				d = msg[1].postln;   //bussola
				e = msg[1].linlin(0, 360, 3000,300);
				if (d<=180,
					{
						Synth(\risset, [\freq, e, \amp, 0.1]);
					},
					{
						Synth(\risset, [\freq, (3000-e), \amp, 0.1]);
				})
			},
			'/gyrosc/comp');}, {CmdPeriod.run;});});



~buttonMelody1 = Button(w, Rect(left:380, top:100, width:160, height:30))
.font_(Font("Arial", size:12, bold:false))
.states_([
	["MAGIC CAMPING", Color.white, Color(0.71, 0.62, 0.26)],
	["OFF", Color.white, Color(0.71, 0.71, 0.71)] ])
.action_({
	arg obj;
	if (obj.value==1,{

		//Pbind for Hedwig's theme
		var qu=0.645161, ei=0.322581, si=0.16129, dq=0.967742, de=0.483871, osc;
		osc=Prand([0.5,0.6,0.7,0.8,0.9,1], inf);
		Pbind(\instrument, \risset,
			\freq, (Pseq.new([62,67,70,69,67,74,72,69, 67,70,69,65,68,62,62, \rest, 62,67,70, 69, 67,75,77,76,75,71,  76,74,73,61,70,  67,67]+24, inf)).midicps,
			\dur, (Pseq.new([ei,de,si,ei,qu,ei,dq,dq,  de,si,ei,qu,ei,dq,de,si,ei,de,si,ei,qu,ei,qu,ei,qu,ei, de,si,ei,qu,ei,  dq,qu   ], inf)),
			\pan, osc,
			\mix, 0.3,
			\amp, 0.1;
		).play;

		//firesound
		(
			~firegen = {
				var trigs, durscale, resfreq;
				var noise, hissing, crackles, lapping;
				var pan=1;
				// A common noise source
				noise = PinkNoise.ar;
				// Hissing
				hissing = HPF.ar(noise, 1000) * LFNoise2.kr(1).squared.squared;
				// Crackle
				trigs = Dust.kr(1);
				durscale = TRand.kr(0.3, 1.5, trigs); // vary duration
				resfreq = TExpRand.kr(100, 1000, trigs); // different resonant frequency for each one
				crackles = noise * EnvGen.ar(Env.perc(0, 0.02, curve: 0), trigs, timeScale: durscale);
				crackles = crackles + BPF.ar(crackles, resfreq, 20);
				// Flame
				lapping = LeakDC.ar(LeakDC.ar(BPF.ar(noise, 30, 0.2) * 50).clip2(0.9)) * 0.5;
				// Combine them:
				c=((([crackles, hissing, lapping] * [0.4, 0.05, 0.2]).sum * 3)!2);
				LinPan2.ar( in:c, pos:-0.3, level:1);
			};
			~firegen.play
		);

		//crickets
		(
			(
				a = {
					var modulator, mod1, mod2, mod3, osc;

					// repeat time is 0.7s: equates to 1.43 Hz.
					modulator = LFSaw.ar(1.43, 1, 0.5, 0.5);
					mod2 = (modulator * 40.6 * 2pi).cos.squared;
					mod3 = modulator * 3147;
					mod3 = (mod3 * 2pi).cos + ((mod3 * 2 * 2pi).cos * 0.3);
					mod1 = ((Wrap.ar(modulator.min(0.1714) * 5.84) - 0.5).squared * (-4) + 1) * (mod2 * mod3);
					osc = SinOsc.kr(1, 0, 1, 0);  //for amp modulation
					mod1 = osc*(mod1 * 0.1)!2;
				}.play;
			)
		)
		},
		{
			CmdPeriod.run;

		};
	);
});


~buttonMelody2 = Button(w, Rect(left:20, top:100, width:160, height:30))
.font_(Font("Arial", size:12, bold:false))
.states_([
	["SUMMER IN THE SHIRE", Color.white, Color(0.71, 0.62, 0.26)],
	["OFF", Color.white, Color(0.71, 0.71, 0.71)] ])
.action_({
	arg obj;
	if (obj.value==1,{
		var ha=1.666667, dq= 1.25, de=0.625, qu=0.833333, ei=0.416667, si=0.208333;
		Pbind(\instrument, \risset,
			\dur, (Pseq.new([si,si,ei,ei,ei,ei,de,si,si,si,  qu,qu,ei,qu,ei,  dq,ei,dq,qu,  qu,si,si,dq,si,si,  qu,qu,si,si,ei,dq,si,  ha], inf)),
			\freq, (Pseq.new([ 62,64,66,66,69,69,66,64,66,64,  62, \rest, \rest, 66,69,  71,74,73,69,  66,68,66,64,62,64,  66,69,66,64,64,62,64,  62]+24, inf).midicps),
			\pan, -0.8,
			\amp, 0.1,
			\mix, 0;

		).play;

		//CICADAS
		(
			c = {
				var sig, trig, seq, freq, mul, vals;

				trig = Impulse.kr(0.2);
				vals = [
					[0.5, 128],
					[8,6],
					[30,3]
				];
				freq = TChoose.kr(trig, vals);


				sig = WhiteNoise.ar;

				sig = (sig - OnePole.ar(sig, exp(-2pi * (8000 * SampleDur.ir))));
				sig = (sig - OnePole.ar(sig, exp(-2pi * (8000 * SampleDur.ir))));
				sig = OnePole.ar(sig, exp(-2pi * (10000 * SampleDur.ir)));
				sig = OnePole.ar(sig, exp(-2pi * (10000 * SampleDur.ir)));
				sig = sig * 5;


				sig = BPF.ar(sig, [7500, 5500], 40.reciprocal).sum * SinOsc.ar(500);
				sig = sig * (1 / (SinOsc.ar( freq[0], 0, freq[1] ).squared + 1));
				sig = (sig - OnePole.ar(sig, exp(-2pi * (4000 * SampleDur.ir)))) * 4.dup;
				sig = BPF.ar(sig, freq=2000);
			}.play
		);

		},
		{
			CmdPeriod.run;

		};
	);
});

// TOOLTIPS DEFINITIONS
~buttonHitTheBell.toolTip = "Lash your smartphone around to hit the bell (works best at 5Hz data send)";
~buttonBell.toolTip = "Play the bells and control their amplitude and panning by tilting your smarthphone (works best at 30Hz data send)";
~buttonMelody1.toolTip = "Sit in front of a campfire surrounded by crickets and enjoy a little melody";
~buttonMelody2.toolTip = "In this hot summer afternoon you can see the green hills of the Shire right outside the window";
~buttonFollow.toolTip = "Rotate on the spot and follow the bells as the pitch grows higher (works best at 5Hz)";

)



