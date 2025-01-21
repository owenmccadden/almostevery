'use client';

import React, { useState, useEffect } from 'react';
import { FixedSizeList as List } from 'react-window';
import AutoSizer from 'react-virtualized-auto-sizer';
import { Code, HelpCircle } from 'lucide-react';
import { shuffle } from 'lodash';

const XIcon = ({ size = 18, className }) => (
  <svg 
    width={size} 
    height={size} 
    viewBox="0 0 24 24" 
    fill="none" 
    stroke="currentColor" 
    className={className}
  >
    <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
  </svg>
);

const Row = ({ data, index, style }) => {
  const domain = data[index];
  return (
    <div style={style}>
      <a
        href={`https://${domain}`}
        target="_blank"
        rel="noopener noreferrer"
        className="px-3 py-1.5 h-full flex items-center justify-between group hover:bg-white/50 transition-all duration-150"
      >
        <span className="font-mono text-sm text-gray-800">{domain}</span>
        <span className="text-blue-600 opacity-0 group-hover:opacity-100 transform group-hover:translate-x-0 -translate-x-2 transition-all duration-150 font-mono">
          →
        </span>
      </a>
    </div>
  );
};

export default function VercelDomains({ initialDomains }) {
  // Initialize with shuffled domains
  const [allDomains] = useState(() => shuffle([...initialDomains]));
  const [filteredDomains, setFilteredDomains] = useState(allDomains);
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    const filtered = allDomains.filter(domain =>
      domain.toLowerCase().includes(searchTerm.toLowerCase())
    );
    setFilteredDomains(filtered);
  }, [searchTerm, allDomains]);

  return (
    <div className="h-screen flex flex-col bg-[#faf8f4]">
      <header className="sticky top-0 bg-[#faf8f4]/80 backdrop-blur-md px-4 sm:px-6 pt-6 sm:pt-8 pb-4 z-10 border-b border-[#e9e6e0]">
        <div className="flex flex-col sm:flex-row sm:items-start justify-between mb-6 max-w-5xl mx-auto gap-4 sm:gap-0">
          <div>
            <h1 className="text-2xl sm:text-3xl font-mono font-bold tracking-tight text-gray-900">
              every vercel.app
            </h1>
            <div className="flex items-center gap-2 mt-2">
              <p className="text-gray-600 font-mono text-sm">
                well, almost every...
              </p>
              <a 
                href="https://owenmc.dev/posts/every-vercel-app" 
                target="_blank" 
                rel="noopener noreferrer"
                className="text-gray-500 hover:text-gray-700 transition-colors"
                aria-label="About this project"
              >
                <HelpCircle size={18} />
              </a>
            </div>
          </div>
          <div className="flex flex-row justify-between sm:justify-end items-center w-full sm:w-auto sm:gap-8 text-sm font-mono">
            <a 
              href="https://owenmc.dev" 
              target="_blank" 
              rel="noopener noreferrer"
              className="text-gray-600 hover:text-gray-900 transition-colors"
            >
              Created by owenmcdev
            </a>
            <div className="flex gap-3 sm:gap-4">
              <a 
                href="https://x.com/owenmcdev" 
                target="_blank" 
                rel="noopener noreferrer"
                className="text-gray-500 hover:text-gray-900 transition-colors p-1 hover:bg-white/70 rounded-md"
                aria-label="Twitter"
              >
                <XIcon size={18} />
              </a>
              <a 
                href="https://github.com/owenmccadden/almostevery" 
                target="_blank" 
                rel="noopener noreferrer"
                className="text-gray-500 hover:text-gray-900 transition-colors p-1 hover:bg-white/70 rounded-md"
                aria-label="Source code"
              >
                <Code size={18} />
              </a>
            </div>
          </div>
        </div>
        
        <div className="max-w-5xl mx-auto space-y-3">
          <input
            type="text"
            placeholder="Search domains..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full px-4 py-2.5 bg-white border border-[#e9e6e0] rounded-lg font-mono text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500/50 transition-shadow"
          />
          
          <div className="text-sm text-gray-600 font-mono pl-1">
            {filteredDomains.length.toLocaleString()} domains found
          </div>
        </div>
      </header>

      <div className="flex-1 max-w-5xl mx-auto w-full">
        <AutoSizer>
          {({ height, width }) => (
            <List
              height={height}
              itemCount={filteredDomains.length}
              itemSize={36}
              width={width}
              itemData={filteredDomains}
              className="scrollbar-thin scrollbar-thumb-gray-200 scrollbar-track-transparent"
            >
              {Row}
            </List>
          )}
        </AutoSizer>
      </div>
    </div>
  );
}