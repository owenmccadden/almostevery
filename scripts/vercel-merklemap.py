import requests
import csv
import time
from typing import Dict, List
from datetime import datetime
import argparse
import sys

class MerkleMapScraper:
    def __init__(self, last_page: int = 11088, sleep_time: float = 1.0, resume_page: int = 0):
        self.output_file = 'vercel_domains.csv'
        self.last_page = last_page
        self.sleep_time = sleep_time
        self.resume_page = resume_page
        self.processed_pages = 0
        self.start_time = None
        
    def fetch_page(self, page: int) -> Dict:
        """Fetch a single page from the MerkleMap API"""
        url = 'https://api.merklemap.com/search'
        params = {
            'query': '*.vercel.app',
            'page': page
        }
        
        response = requests.get(url, params=params)
        response.raise_for_status()
        return response.json()

    def process_results(self, results: List[Dict]) -> List[Dict]:
        """Process the results and convert timestamps to readable dates"""
        processed = []
        for result in results:
            processed.append({
                'domain': result['domain'],
                'subject_common_name': result['subject_common_name'],
                'not_before': datetime.fromtimestamp(result['not_before']).isoformat()
            })
        return processed

    def save_to_csv(self, data: List[Dict], is_first_write: bool):
        """Save the results to a CSV file"""
        if not data:
            return
            
        mode = 'w' if is_first_write else 'a'
        with open(self.output_file, mode, newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=data[0].keys())
            if is_first_write:
                writer.writeheader()
            writer.writerows(data)

    def print_progress(self, page: int):
        """Print progress information"""
        elapsed_time = time.time() - self.start_time
        pages_per_second = self.processed_pages / elapsed_time
        estimated_completion = (self.last_page - self.processed_pages) / pages_per_second if pages_per_second > 0 else 0
        
        print(f"Processed page {page}/{self.last_page} | "
              f"Progress: {(self.processed_pages/(self.last_page+1))*100:.1f}% | "
              f"Rate: {pages_per_second:.2f} pages/sec | "
              f"Est. completion: {estimated_completion/60:.1f} minutes | "
              f"Sleep time: {self.sleep_time:.2f}s")

    def run(self):
        """Run the scraper synchronously with sleep between requests"""
        self.start_time = time.time()
        is_first_write = True if self.resume_page == 0 else False
        
        for page in range(self.resume_page, self.last_page + 1):
            try:
                data = self.fetch_page(page)
                processed_results = self.process_results(data['results'])
                self.save_to_csv(processed_results, is_first_write)
                is_first_write = False
                
                self.processed_pages += 1
                self.print_progress(page)
                
                # Sleep between requests
                time.sleep(self.sleep_time)
                
            except requests.exceptions.HTTPError as e:
                if e.response.status_code == 429:  # Rate limited
                    print(f"\nRate limited on page {page}. Current sleep time: {self.sleep_time}")
                    print("Try increasing the sleep time using --sleep argument")
                    sys.exit(1)
                else:
                    print(f"\nHTTP error on page {page}: {e}")
                    sys.exit(1)
                    
            except Exception as e:
                print(f"\nUnexpected error on page {page}: {e}")
                sys.exit(1)
        
        total_time = (time.time() - self.start_time) / 60
        print(f"\nScraping completed!")
        print(f"Successfully processed {self.processed_pages} pages")
        print(f"Total time: {total_time:.1f} minutes")

def main():
    parser = argparse.ArgumentParser(description='Scrape MerkleMap API for Vercel domains')
    parser.add_argument('-p', '--pages', type=int, default=11088,
                      help='Last page number to scrape (default: 11088)')
    parser.add_argument('-s', '--sleep', type=float, default=1.0,
                      help='Sleep time between requests in seconds (default: 1.0)')
    parser.add_argument('-r', '--resume', type=int, default=0,
                      help='Resume from page number (default: 0)')
    
    args = parser.parse_args()
    
    print(f"Starting scraper with {args.sleep}s sleep time, scraping through page {args.pages}")
    if args.resume > 0:
        print(f"Resuming from page {args.resume}")
    
    scraper = MerkleMapScraper(
        last_page=args.pages,
        sleep_time=args.sleep,
        resume_page=args.resume
    )
    scraper.run()

if __name__ == "__main__":
    main()