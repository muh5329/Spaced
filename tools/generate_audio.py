"""Generate original, deterministic ambient music and effects using only Python stdlib."""
from pathlib import Path
import array, math, random, wave

ROOT = Path(__file__).resolve().parents[1] / "assets" / "audio"
ROOT.mkdir(parents=True, exist_ok=True)
RATE = 22050
random.seed(47)

def write(name, seconds, sample):
    frames = array.array("h")
    for i in range(int(seconds * RATE)):
        t = i / RATE
        value = max(-1, min(1, sample(t, seconds)))
        frames.append(int(value * 24000))
    with wave.open(str(ROOT / (name + ".wav")), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(frames.tobytes())

def ambient(t, duration):
    fade = min(1, t / 2, (duration-t) / 2)
    result = 0
    for j, hz in enumerate([55, 110, 164.8138, 220, 261.6256, 329.6276]):
        result += math.sin(t * math.tau * hz + 0.35 * math.sin(t * .13 + j)) * (.034 if j < 3 else .018) * (.65 + .35 * math.sin(t * .16 + j))
    pulse = (t % 4.0)
    result += math.sin(t * math.tau * [440, 659.255, 523.25, 329.63, 392, 293.66][int(t / 4) % 6]) * math.exp(-pulse * 1.2) * .035
    return result * fade

write("adrift", 48, ambient)
write("rail", .19, lambda t,d: (math.sin(math.tau*(1500*t-2700*t*t))*.55 + random.uniform(-1,1)*.15) * math.exp(-t*32))
write("hostile", .26, lambda t,d: math.sin(math.tau*(330*t-370*t*t)) * .4 * math.exp(-t*16))
write("impact", .22, lambda t,d: random.uniform(-1,1) * .5 * math.exp(-t*24))
write("explosion", 1.1, lambda t,d: (random.uniform(-1,1)*.55+math.sin(t*math.tau*47)*.3)*math.exp(-t*5)*min(1,t*120))
write("collect", .7, lambda t,d: math.sin(t*math.tau*(660 if t < .18 else 880 if t < .36 else 1320))*.19*math.exp(-(t%.18)*15)*min(1,(d-t)*9))
write("scan", 1.4, lambda t,d: math.sin(math.tau*(170*t+460*t*t))*.13*math.sin(t/d*math.pi)**2)
write("ui", .09, lambda t,d: math.sin(t*math.tau*880)*.2*math.exp(-t*50))
write("dock", 1.8, lambda t,d: sum(math.sin(t*math.tau*f) for f in [220,329.6276,440])*.08*math.sin(t/d*math.pi)**2)
print(f"Generated 9 original audio assets in {ROOT}")
