'use strict';
// Fibonacci DNA braid: finite demonstrator, not a physical universe simulation.
const assert = require('node:assert/strict');
const A=0, B=1;
const DNA=['A','T'];
function fibonacciWords(count) {
  assert(Number.isSafeInteger(count) && count>=2 && count<=24);
  let words=[Uint8Array.of(A),Uint8Array.of(A,B)];
  for(let i=2;i<count;i++) {
    const out=new Uint8Array(words[i-1].length+words[i-2].length);
    out.set(words[i-1]);out.set(words[i-2],words[i-1].length);
    words.push(out);
  }
  for(let i=2;i<words.length;i++) {
    assert.equal(words[i].length,words[i-1].length+words[i-2].length);
    assert.deepEqual(Array.from(words[i].slice(0,words[i-1].length)),Array.from(words[i-1]));
  }
  return words;
}
// Invertible braid of two equal-length bit lanes: (x,y)->(y,x XOR y).
function braid(x,y) {
  assert.equal(x.length,y.length);
  const z=new Uint8Array(x.length);
  for(let i=0;i<z.length;i++) {assert(x[i]<2 && y[i]<2);z[i]=x[i]^y[i];}
  return [y.slice(),z];
}
function unbraid(a,b) {
  assert.equal(a.length,b.length);
  const x=new Uint8Array(a.length);
  for(let i=0;i<x.length;i++) x[i]=a[i]^b[i];
  return [x,a.slice()];
}
// 0 -> 0000, 1 -> 1111. Every codeword has weight divisible by 4.
function encodeDoublyEven(bits) {
  const out=new Uint8Array(bits.length*4);
  bits.forEach((bit,i)=> {assert(bit===0||bit===1);out.fill(bit,i*4,i*4+4);});
  return out;
}
function decodeDoublyEven(code) {
  assert.equal(code.length%4,0);
  const bits=new Uint8Array(code.length/4);
  for(let i=0;i<bits.length;i++) {
    const b=code[4*i];
    assert(b===0||b===1);
    for(let j=1;j<4;j++) assert.equal(code[4*i+j],b);
    bits[i]=b;
  }
  return bits;
}
function xor(a,b) {
  assert.equal(a.length,b.length);
  return a.map((x,i)=>x^b[i]);
}
// A generic deterministic Turing-machine runner. Tape is sparse and unbounded in principle;
// execution is always limited by the caller's step budget.
function runTM({blank='_',initial='',head=0,start='q0',halt='HALT',rules,maxSteps=10000}) {
  assert(Number.isSafeInteger(maxSteps)&&maxSteps>=0);
  const tape=new Map([...initial].map((c,i)=>[i,c]));
  let state=start, steps=0;
  while(state!==halt && steps<maxSteps) {
    const symbol=tape.get(head)??blank;
    const rule=rules[`${state}:${symbol}`];
    if(!rule) return {status:'NO_RULE',state,head,steps,tape};
    assert(['L','R','S'].includes(rule.move));
    if(rule.write===blank) tape.delete(head);else tape.set(head,rule.write);
    head+=(rule.move==='R'?1:rule.move==='L'?-1:0);
    state=rule.next; steps++;
  }
  return {status:state===halt?'HALT':'STEP_LIMIT',state,head,steps,tape};
}
function getTape(result) {
  const keys=[...result.tape.keys()];
  if(keys.length===0)return '';
  const low=Math.min(...keys),high=Math.max(...keys);
  return Array.from({length:high-low+1},(_,i)=>result.tape.get(low+i)??'_').join('');
}
// Example Turing machine: binary increment (rightmost bit at input's end).
const incrementRules={
  'scan:0':{write:'0',move:'R',next:'scan'},
  'scan:1':{write:'1',move:'R',next:'scan'},
  'scan:_':{write:'_',move:'L',next:'carry'},
  'carry:1':{write:'0',move:'L',next:'carry'},
  'carry:0':{write:'1',move:'S',next:'HALT'},
  'carry:_':{write:'1',move:'S',next:'HALT'}
};
function modelWorkload({targetTFLOPS=100,seconds=1,flopsPerStep=1000}={}) {
  assert(targetTFLOPS>0&&seconds>=0&&flopsPerStep>0);
  const operations=targetTFLOPS*1e12*seconds;
  return {hypotheticalTargetTFLOPS:targetTFLOPS,seconds,operations,
    hypotheticalSteps:Math.floor(operations/flopsPerStep),
    note:'A budget projection only. Turing-machine steps and bitwise XOR are NOT floating-point operations.'};
}
function main() {
  const words=fibonacciWords(7);
  const word=words.at(-1); // 21-bit Fibonacci word
  const laneX=word.slice(),laneY=word.map((_,i)=>word[(i+5)%word.length]);
  const [a,b]=braid(laneX,laneY),[rx,ry]=unbraid(a,b);
  assert.deepEqual(rx,laneX);assert.deepEqual(ry,laneY);
  const code=encodeDoublyEven(a);
  assert.deepEqual(decodeDoublyEven(code),a);
  assert.equal(code.reduce((s,b)=>s+b,0)%4,0);
  const code2=encodeDoublyEven(b);
  assert.deepEqual(xor(code,code2),encodeDoublyEven(xor(a,b)));
  const tm=runTM({initial:'1011',start:'scan',rules:incrementRules});
  assert.equal(tm.status,'HALT');assert.equal(getTape(tm),'1100');
  const report={fibonacciLength:word.length,dna: [...word].map(i=>DNA[i]).join(''),
    braidReversible:true,codeLength:code.length,doublyEven:true,
    codeXorClosed:true,turingMachine:{status:tm.status,steps:tm.steps,output:getTape(tm)},
    modeledCapacity:modelWorkload()};
  console.log(JSON.stringify(report,null,2));
}
if(require.main===module)main();
module.exports={fibonacciWords,braid,unbraid,encodeDoublyEven,decodeDoublyEven,runTM,modelWorkload};
