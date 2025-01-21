import VercelDomains from '@/components/VercelDomains';
import { shuffle } from 'lodash';

export default function Home({ domains }) {
  return <VercelDomains initialDomains={domains} />;
}

export async function getStaticProps() {
  const fs = require('fs');
  const path = require('path');
  
  const filePath = path.join(process.cwd(), 'public', 'vercel-domain-list.txt');
  const fileContent = fs.readFileSync(filePath, 'utf8');
  const domains = shuffle(fileContent.trim().split('\n'));

  return {
    props: {
      domains
    }
  };
}