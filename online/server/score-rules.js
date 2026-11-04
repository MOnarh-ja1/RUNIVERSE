export function validateScore(data) {
  const distance=data?.distance, durationMs=data?.duration_ms, coins=data?.coins;
  if(!Number.isSafeInteger(distance)||distance<0||distance>10000000) return 'invalid distance';
  if(!Number.isSafeInteger(durationMs)||durationMs<1000||durationMs>86400000) return 'invalid duration_ms';
  if(!Number.isSafeInteger(coins)||coins<0||coins>1000000) return 'invalid coins';
  if(distance>50+(durationMs/1000)*35) return 'implausible distance';
  return null;
}
