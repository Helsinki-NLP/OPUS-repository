<SMT>
 <!-- this part is relevant to corpus extraction from repository -->
 <user>jorgtied</user>
 <srclang>sv</srclang>
 <trglang>en</trglang>
 <tm id="1" name="para">
   <corpus>RF/xml/en-sv</corpus>
   <filter>
     <sample size="100" skip="50"/>
     <links type="1:1" />
   </filter>
 </tm>
 <lm id="2" name ="mono">
   <corpus>RF/xml/en</corpus>
   <filter>
     <sample size="100" skip="50"/>
     <links type="1:1" />
   </filter>
 </lm>
 <tuning name="tune">
   <corpus>RF/xml/en-sv</corpus>
   <filter>
     <sample size="25"/>
     <links type="1:1" />
   </filter>
 </tuning>
 <evaluation name="eval">
   <corpus>RF/xml/en-sv</corpus>
   <filter>
     <sample skip="25" size="25"/>
     <links type="1:1" />
   </filter>
 </evaluation>

 <!-- various training and decoding options begin here -->
 <srctokenizer>/path/to/tokenizer -parameter or just a tokenizer id?</srctokenizer>
 <trgtokenizer>/path/to/tokenizer -parameter</trgtokenizer>
 <trgdetokenizer>/path/to/detokenizer -parameter</trgdetokenizer>
</SMT>