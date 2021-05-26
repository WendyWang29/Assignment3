s.boot;


(
SynthDef(\risset, {
	| out= 0, pan= 0, freq= 400, amp= 0.3, dur= 2, t_trig=1, del=0.3,
	room=0.5, mix=0.33, a, t=8|
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


(
(
w=Window.new("All About Bells", Rect.new(
	left: Window.screenBounds.width/2-280,
	top: Window.screenBounds.height/2-100,
	width:560,
	height:200))
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

StaticText(w, Rect(left:220, top:100, width:120, height:50))
.string_("🔔")
.align_(\center)
.font_(Font("Arial", size:40))
.stringColor_(Color(0.71, 0.62, 0.26));



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

			MIDIClient.init;
			MIDIIn.connectAll;

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
					p = msg[2].linlin(-1.57, 1.57, -1,1);   //rollio
				},
				'/gyrosc/gyr/gyro');

				OSCdef.new(\ampValue,{
					arg msg, time, addr, port;
					h = msg[1].linlin(-1.57, 1.57, 600,2500);   //beccheggio
					h.postln;
				},
				'/gyrosc/gyr/gyro');

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
			MIDIIn.disconnect;
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
						Synth(\risset);
				})
			},
			'/gyrosc/gyr/accel');
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
						Synth(\risset, [\freq, e]);
					},
					{
						Synth(\risset, [\freq, (3000-e)]);
				})
			},
			'/gyrosc/gyr/comp');}, {CmdPeriod.run;});});



~buttonMelody = Button(w, Rect(left:380, top:100, width:160, height:30))
.font_(Font("Arial", size:14, bold:true))
.states_([
	["TAKE A BREAK", Color.white, Color(0.71, 0.62, 0.26)],
	["OFF", Color.white, Color(0.71, 0.71, 0.71)] ])
.action_({
	arg obj;
	if (obj.value==1,{

		//Pbind for Hedwig's theme
		var qu=0.645161, ei=0.322581, si=0.16129, dq=0.967742, de=0.483871, osc;
		osc=Prand([0.5,0.6,0.7,0.8,0.9,1], inf);
		Pbind(\instrument, \risset,
			\freq, (Pseq.new([65,67,70,69,67,74,72,69, 67,70,69,65,68,62,62, \rest, 62,67,70, 69, 67,75,77,76,75]+24, 1)).midicps,
			\dur, (Pseq.new([ei,de,si,ei,qu,ei,dq,dq,  de,si,ei,qu,ei,dq,de,si,ei,
				de,si,ei,qu,ei,qu,ei,qu ], 1)),
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
				LinPan2.ar( in:c, pos:1, level:1);
			};
			~firegen.play
		);
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
					osc = SinOsc.kr(1, 0, 1, 0);
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

~buttonHitTheBell.toolTip = "Lash your smartphone around to hit the bell";
~buttonBell.toolTip = "Play the bells and control their amplitude and panning \n by tilting your smarthphone";
~buttonMelody.toolTip = "Sit in front of a campfire surrounded \n by crickets  and enjoy a little melody";
~buttonFollow.toolTip = "Rotate on the spot and follow the bells \n as the pitch grows higher";

))

// (
// ~firegen = {
// 	var trigs, durscale, resfreq;
// 	var noise, hissing, crackles, lapping;
// 	var pan=1;
// 	// A common noise source
// 	noise = PinkNoise.ar;
// 	// Hissing
// 	hissing = HPF.ar(noise, 1000) * LFNoise2.kr(1).squared.squared;
// 	// Crackle
// 	trigs = Dust.kr(1);
// 	durscale = TRand.kr(1, 1.5, trigs); // vary duration between default 20ms and 30ms
// 	resfreq = TExpRand.kr(100, 1000, trigs); // different resonant frequency for each one
// 	crackles = noise * EnvGen.ar(Env.perc(0, 0.02, curve: 0), trigs, timeScale: durscale);
// 	crackles = crackles + BPF.ar(crackles, resfreq, 20);
// 	// Flame
// 	lapping = LeakDC.ar(LeakDC.ar(BPF.ar(noise, 30, 0.2) * 50).clip2(0.9)) * 0.5;
// 	// Combine them:
// 	c=((([crackles, hissing, lapping] * [0.1, 0.04, 0.1]).sum * 3)!2);
// 	LinPan2.ar( in:c, pos:1, level:1);
// };
// ~firegen.play
// )


// OSCdef.new(\playTheBell,
// 	{
// 		arg msg, time, addr, port;
// 		a=(msg[1]+msg[2]+msg[3]).postln;   //accellerometro
// 		if (a>2,
// 			{
// 				Synth(\risset1);
// 		})
// 	},
// '/gyrosc/gyr/accel');
//
// OSCdef.new(\bussola,
// 	{
// 		arg msg, time, addr, port;
// 		d = msg[1].postln;   //bussola
// 		e = msg[1].linlin(0, 360, 3000,300);
// 		if (d<=180,
// 			{
// 				Synth(\risset1, [\freq, e]);
// 			},
// 			{
// 				Synth(\risset1, [\freq, (3000-e)]);
// 		})
//
// 	},
// '/gyrosc/gyr/comp');

