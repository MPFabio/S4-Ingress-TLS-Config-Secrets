import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    rps_test: {
      executor: 'constant-arrival-rate',
      rate: 50,
      timeUnit: '1s',
      duration: '5m',
      preAllocatedVUs: 20,
      maxVUs: 50
    }
  },
  thresholds: {
    http_req_duration: ['p(95)<300'],
    http_req_failed: ['rate<0.01'],
    http_reqs: ['rate>45']
  }
};

export default function() {
  const res = http.get('http://workshop.local:8080/api/status/200');
  
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 300ms': (r) => r.timings.duration < 300
  });
  
  sleep(0.1);
}

export function handleSummary(data) {
  return {
    'summary.txt': textSummary(data, { indent: ' ', enableColors: false }),
    'results.json': JSON.stringify(data, null, 2)
  };
}

function textSummary(data, options) {
  const indent = options.indent || '';
  const enableColors = options.enableColors !== false;
  
  let summary = `
${indent}Résultats du test de charge
${indent}=============================

${indent}Durée totale: ${data.metrics.iteration_duration.values.avg.toFixed(2)}ms
${indent}Requêtes totales: ${data.metrics.http_reqs.values.count}
${indent}Requêtes/sec: ${data.metrics.http_reqs.values.rate.toFixed(2)}
${indent}Échecs: ${data.metrics.http_req_failed ? data.metrics.http_req_failed.values.rate.toFixed(4) : 'N/A'}

${indent}Latence:
${indent}  p50: ${data.metrics.http_req_duration.values['p(50)'].toFixed(2)}ms
${indent}  p95: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms
${indent}  p99: ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms

${indent}Statut HPA: ${data.metrics.http_req_duration.values['p(95)'] < 300 ? 'PASS' : 'FAIL'}
`;
  
  return summary;
}



