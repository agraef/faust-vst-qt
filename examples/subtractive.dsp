
declare name "subtractive";
declare description "saw wave filtered with resonant lowpass";
declare author "Albert Graef";
declare version "1.0";
declare nvoices "16";

import("music.lib");

// groups

mstr(x)	= hgroup("[1]", x); // master
modl(x)	= hgroup("[2]", x); // modulation (aux synth params)
env1(x)	= vgroup("[3]", x); // (first) envelop
note(x)	= hgroup("[4]", x); // note a.k.a. per-voice params

// control variables

// master volume and pan
vol	= vslider("vol [style:knob] [midi:ctrl 7]", 0.3, 0, 10, 0.01);	// %
pan	= vslider("pan [style:knob] [midi:ctrl 8]", 0.5, 0, 1, 0.01);	// %

// ADSR envelop
attack	= hslider("[1] attack", 0.01, 0, 1, 0.001);	// sec
decay	= hslider("[2] decay", 0.3, 0, 1, 0.001);	// sec
sustain = hslider("[3] sustain", 0.5, 0, 1, 0.01);	// %
release = hslider("[4] release", 0.2, 0, 1, 0.001);	// sec

// filter parameters
res	= vslider("res [unit:dB] [style:knob]", 3, 0, 20, 0.1);
cutoff	= vslider("cutoff [style:knob]", 6, 1, 20, 0.1);

// voice parameters
freq	= nentry("freq", 440, 20, 20000, 1);	// Hz
gain	= nentry("gain", 1, 0, 10, 0.01);	// %
gate	= button("gate");			// 0/1

// generic table-driven oscillator with phase modulation

// n	= the size of the table, must be a power of 2
// f	= the wave function, must be defined on the range [0,2*PI]
// freq	= the desired frequency in Hz
// mod	= the phase modulation signal, in radians

tblosc(n,f,freq,mod)	= (1-d)*rdtable(n,wave,i&(n-1)) +
			  d*rdtable(n,wave,(i+1)&(n-1))
with {
	wave	 	= time*(2.0*PI)/n : f;
	phase		= freq/SR : (+ : decimal) ~ _;
	modphase	= decimal(phase+mod/(2*PI))*n;
	i		= int(floor(modphase));
	d		= decimal(modphase);
};

// resonant lowpass

// This is a tweaked Butterworth filter by David Werner and Patrice Tarrabia,
// see http://www.musicdsp.org and http://www.experimentalscene.com for
// details.

// res = resonance in dB above DC gain
// freq = cutoff frequency

lowpass(res,freq)	= f : (+ ~ g) : *(a)
with {
	f(x)	= a0*x+a1*x'+a2*x'';
	g(y)	= 0-b1*y-b2*y';
	a	= 1/db2linear(0.5*res);

	c	= 1.0/tan(PI*(freq/SR));
	c2	= c*c;
	r	= 1/db2linear(2.0*res);
	q	= sqrt(2.0)*r;
	a0	= 1.0/(1.0+(q*c)+(c2));
	a1	= 2.0*a0;
	a2	= a0;
	b1	= 2.0*a0*(1.0-c2);
	b2	= a0*(1.0-q*c+c2);
};

// subtractive synth (saw wave passed through resonant lowpass)

saw(x)	= x/PI-1;

smooth(c) = *(1-c) : +~*(c);

process	= tblosc(1<<16, saw, note(freq), 0) : ((env,note(freq),_) : filter) :
	  *(env * (note(gain)))
        : mstr(*(vol:smooth(0.99)) : panner(pan:smooth(0.99)))
with {
  env = note(gate) : env1(adsr(attack, decay, sustain, release));
  filter(env,freq)
      = modl(lowpass(env*res, fmax(1/cutoff, env)*freq*cutoff));
};
