
1 => int midiDeviceIndex;
1 => int enableOsc;

3 => int SLIDER_BREADTH_ID;  // harmonic scalar
9 => int SLIDER_SPEED_ID;    // how fast we go thru seq
12 => int SLIDER_BALANCE_ID; // adjust voices gain
14 => int SLIDER_MONITOR_ID; // monitor
15 => int SLIDER_LPF_ID;     // global lpf

0 => float breadth;
10 => float tremorFreq;

12 => int PAD_MAX_SEQ_ID;
// boolean array indicating whether pads 0 - (PAD_MAX_SEQ_ID-1) are active
int isActive[PAD_MAX_SEQ_ID];
// ordered list of active pad ids (of length sequenceLength)
int sequence[PAD_MAX_SEQ_ID];
0 => int sequenceLength;

12 => int PAD_SPAWN_SAMPLER_ID;
13 => int PAD_STOP_SAMPLERS_ID;
15 => int PAD_REMOVE_FROM_SEQ_ID;
0 => int isRemovingFromSequence;

3 => int NUM_VOICES;
0 => float voiceBalance;
Tremor voices[NUM_VOICES];

class ParamEvent extends Event {
    int paramId;
}
ParamEvent evtParam;
Event evtStopSamplers;
OscSend oscTransmitter;

LPF lpfLeft => dac.left;
20000 => lpfLeft.freq;
0.98 => lpfLeft.Q;

LPF lpfRight => dac.right;
lpfLeft.freq() => lpfRight.freq;
lpfLeft.Q() => lpfRight.Q;

adc.left => Gain gMonitor => lpfLeft;
0 => gMonitor.gain;

// midi control
fun void listenForMidi() {
    MidiIn min;
    MidiMsg msg;
    if (!min.open(midiDeviceIndex)) me.exit();
    while (true) {
        min => now;
        while (min.recv(msg)) {
            if (msg.data1 == 153) { // note on
                msg.data2 - 36 => int padIndex;
                if (padIndex >= 0 && padIndex < PAD_MAX_SEQ_ID) {
                    1 => isActive[padIndex];
                    recomputeSequence();
                    <<< "Add", padIndex + 1 >>>;
                    if (enableOsc) {
                        // 1 -> pad
                        transmitOscValue(1, padIndex, 1, "");
                    }
                } else if (padIndex == PAD_SPAWN_SAMPLER_ID) {
                    Sampler s;
                    // TODO: make input less of a hack here
                    spork ~ s.loop(voices[0]._pitShift, lpfRight);
                    <<< "Loop" >>>;
                } else if (padIndex == PAD_STOP_SAMPLERS_ID) {
                    evtStopSamplers.broadcast();
                    <<< "Stop loops" >>>;
                } else if (padIndex == PAD_REMOVE_FROM_SEQ_ID) {
                    1 => isRemovingFromSequence;
                    <<< "Enable removal" >>>;
                    for (0 => int ii; ii < sequenceLength; ii++) {
                        <<< "    Active: ", sequence[ii] + 1 >>>;
                    }
                }
            } else if (msg.data1 == 137) {
                msg.data2 - 36 => int padIndex;
                if (isRemovingFromSequence &&
                    padIndex >= 0 && padIndex < PAD_MAX_SEQ_ID) {
                    0 => isActive[padIndex];
                    recomputeSequence();
                    <<< "Remove", padIndex + 1 >>>;
                    if (enableOsc) {
                        // 1 -> pad
                        transmitOscValue(1, padIndex, 0, "");
                    }
                } else if (padIndex == PAD_REMOVE_FROM_SEQ_ID) {
                    0 => isRemovingFromSequence;
                }
            } else if (msg.data1 == 176) { // knob twist
                // which knob
                " " => string description;
                if (msg.data2 == SLIDER_BREADTH_ID) {
                    (msg.data3$float / 127.0) => float amount;
                    (0.99 * amount) + 0.01 => breadth;
                    SLIDER_BREADTH_ID => evtParam.paramId;
                    evtParam.broadcast();
                    <<< "Breadth:", breadth >>>;
                } else if (msg.data2 == SLIDER_SPEED_ID) {
                    (msg.data3$float / 127.0) => float amount;
                    10.0 + (amount * 90.0) => tremorFreq;
                    SLIDER_SPEED_ID => evtParam.paramId;
                    evtParam.broadcast();
                    <<< "Freq:", tremorFreq >>>;
                } else if (msg.data2 == SLIDER_LPF_ID) {
                    msg.data3 $ float / 127.0 => float val;
                    Math.pow(2, val * 14.287) => lpfLeft.freq;
                    lpfLeft.freq() => lpfRight.freq;
                    <<< "Lowpass", lpfLeft.freq() >>>;
                    lpfLeft.freq() + " lo Hz" => description;
                } else if (msg.data2 == SLIDER_BALANCE_ID) {
                    msg.data3 $ float / 127.0 => voiceBalance;
                    updateBalance();
                    <<< "Balance", voiceBalance >>>;
                } else if (msg.data2 == SLIDER_MONITOR_ID) {
                    (msg.data3$float / 127.0) => float amount;
                    amount => gMonitor.gain;
                    <<< "Monitor", amount >>>;
                    amount * 100 + "%" => description;
                }
                if (enableOsc) {
                    // 0 -> knob
                    transmitOscValue(0, msg.data2, msg.data3, description);
                }
            } else {
                // <<< msg.data1 >>>;
            }
        }
    }
}

fun void recomputeSequence() {
    0 => sequenceLength;
    for (0 => int ii; ii < isActive.cap(); ii++) {
        if (isActive[ii]) {
            ii => sequence[sequenceLength];
            sequenceLength++;
        }
    }
}

fun void spawnVoices() {
    for (0 => int ii; ii < NUM_VOICES; ii++) {
        spork ~ voices[ii].run(adc.left, lpfRight, ii);
    }
    updateBalance();
}

fun void updateBalance() {
    // voices[0] is always full gain
    voices[0].setGain(1.0);
    
    // voices 1..N ramp in at equal intervals
    1.0 / (NUM_VOICES $ float) => float increment;
    for (1 => int ii; ii < NUM_VOICES; ii++) {
        (ii $ float) * increment => float threshold;
        Math.min(1.0, voiceBalance / threshold) => float gain;
        voices[ii].setGain(gain);
    }
}

class Tremor {
    PitShift _pitShift;
    float _breadth;
    dur _tremorPeriod;
    0 => int _stepOffset;

    fun void run(UGen input, UGen output, int stepOffset) {
        input => _pitShift => ADSR _env => output;
        stepOffset => _stepOffset;
        1 => _pitShift.mix;
        _env.set(0::ms, 2::ms, 0.94, 0::ms);
        _updateBounds();
        _updateTremorPeriod();

        spork ~ _listenForParam();
        0 => int stepIndex;
        1 => _env.keyOn;
        while (_tremorPeriod => now) {
            if (sequenceLength == 0) {
                1.0 + (_stepOffset * _breadth) => _pitShift.shift;
            } else {
                // Math.pow(2.0, sequence[stepIndex] * _breadth) => _pitShift.shift;
                // (1.0 + sequence[stepIndex]) * _breadth => _pitShift.shift;
                // max param: 1, 2, 3, 4, 5, 6, 7, 8...
                // min param: 1, 1, 1, 1, 1, 1, 1, 1...
                1.0 + ((_stepOffset + sequence[stepIndex]) * _breadth) => _pitShift.shift;
                stepIndex++;
                if (stepIndex >= sequenceLength) {
                    0 => stepIndex;
                    1 => _env.keyOff;
                    _env.releaseTime() + 5::samp => now;
                    1 => _env.keyOn;
                }
            }
        }
    }

    fun void setGain(float gain) {
        gain => _pitShift.gain;
    }

    fun void _listenForParam() {
        while (evtParam => now) {
            if (evtParam.paramId == SLIDER_BREADTH_ID) {
                _updateBounds();
            } else if (evtParam.paramId == SLIDER_SPEED_ID) {
                _updateTremorPeriod();
            }
        }
    }

    fun void _updateBounds() {
        breadth => _breadth;
    }

    fun void _updateTremorPeriod() {
        (1.0 / tremorFreq)::second => _tremorPeriod;
    }
}

class Sampler {
    0 => int _isStopped;
    ADSR _env;

    // spawn a sample loop which is exactly one sequence long (at time of spawn)
    fun void loop(UGen in, UGen out) {
        in => LiSa buf => _env => out;
        _env.set(0.1::second, 0.1::second, 0.9, 5::second);

        ((1.0 / tremorFreq) * sequenceLength)::second => dur sampleLength;
        sampleLength => buf.duration;
        buf.recRamp(10::ms);
        buf.record(1);
        sampleLength => now;
        buf.record(0);

        buf.play(1);
        1 => _env.keyOn;
        spork ~ _listenForStop();
        while (!_isStopped) {
            sampleLength => now;
        }
        1 => _env.keyOff;
        _env.releaseTime() => now;
        _env =< out;
    }

    fun void _listenForStop() {
        evtStopSamplers => now;
        1 => _isStopped;
    }
}

fun void transmitOscValue(int type, int param, int value, string description) {
    oscTransmitter.startMsg("/param", "i i i s");
    type => oscTransmitter.addInt;
    param => oscTransmitter.addInt;
    value => oscTransmitter.addInt;
    description => oscTransmitter.addString;
    return;
}

if (enableOsc) {
    oscTransmitter.setHost("localhost", 4242);
}
spork ~ listenForMidi();
spawnVoices();
while (1::day => now);
