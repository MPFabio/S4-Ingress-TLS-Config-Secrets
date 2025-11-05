import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 5 },
    { duration: '10s', target: 100 },
    { duration: '1m', target: 100 },
    { duration: '10s', target: 5 },
    { duration: '10s', target: 0 }
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'],
    http_req_failed: ['rate<0.1']
  }
};

export default function() {
  const endpoints = [
    'http://workshop.local:8080/api/get',
    'http://workshop.local:8080/api/headers',
    'http://workshop.local:8080/front'
  ];
  
  const res = http.get(endpoints[Math.floor(Math.random() * endpoints.length)]);
  
  check(res, {
    'status is 200': (r) => r.status === 200
  });
  
  sleep(0.5);
}

