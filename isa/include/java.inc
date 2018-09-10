

<script type="text/javascript">
// <![CDATA[

	function setStyle(obj,style,value){
		obj.style[style] = value;
	}
	
	function getRef(obj){
		return (typeof obj == "string") ?
			 document.getElementById(obj) : obj;
	}

        function markAligned(obj,s,t,l){
	  //	    obj.style["border"] = "2pt solid #0000ff";
	    document.getElementById(t).style["color"] = "#bb0000";
	    document.getElementById(s).style["color"] = "#bb0000";
	    document.getElementById(t).style["backgroundColor"] = "#ffffcc";
	    document.getElementById(s).style["backgroundColor"] = "#ffffcc";
	    document.getElementById(l).style["color"] = "#bb0000";
	    document.getElementById(l).style["backgroundColor"] = "#ffffcc";
	    document.getElementById('w'+t).style["color"] = "#bb0000";
	    document.getElementById('w'+s).style["color"] = "#bb0000";
	    document.getElementById('w'+t).style["backgroundColor"]= "#ffffcc";
	    document.getElementById('w'+s).style["backgroundColor"]= "#ffffcc";
        }

        function unmarkAligned(obj,s,t,color,l){
	  //	    obj.style["border"] = "2pt solid " + color;
	    document.getElementById(t).style["color"] = "black";
	    document.getElementById(s).style["color"] = "black";
	    document.getElementById(t).style["backgroundColor"] = "#eeeeaa";
	    document.getElementById(s).style["backgroundColor"] = "#eeeeaa";
	    document.getElementById(l).style["color"] = "black";
	    document.getElementById(l).style["backgroundColor"] = "#eeeeaa";
	    document.getElementById('w'+t).style["color"] = "black";
	    document.getElementById('w'+s).style["color"] = "black";
	    document.getElementById('w'+t).style["backgroundColor"]= "#ffffff";
	    document.getElementById('w'+s).style["backgroundColor"]= "#ffffff";
        }

        function markUnaligned(obj,s,t,l){
	  //	    obj.style["border"] = "2pt solid #0000ff";
	  obj.style["color"] = "#bb3333";
	    document.getElementById(t).style["color"] = "#bb0000";
	    document.getElementById(s).style["color"] = "#bb0000";
	    document.getElementById(t).style["backgroundColor"] = "#ffffcc";
	    document.getElementById(s).style["backgroundColor"] = "#ffffcc";
	    document.getElementById('w'+t).style['color'] = "#bb0000";
	    document.getElementById('w'+s).style["color"] = "#bb0000";
	    document.getElementById('w'+t).style["backgroundColor"]= "#ffffcc";
	    document.getElementById('w'+s).style["backgroundColor"]= "#ffffcc";
        }

        function unmarkUnaligned(obj,s,t,color,l){
	  //	    obj.style["border"] = "2pt solid " + color;
	  obj.style["color"] = "#000000";
	    document.getElementById(t).style["color"] = "black";
	    document.getElementById(s).style["color"] = "black";
	    document.getElementById(t).style["backgroundColor"] = "#eeeeaa";
	    document.getElementById(s).style["backgroundColor"] = "#eeeeaa";
	    document.getElementById('w'+t).style["color"] = "black";
	    document.getElementById('w'+s).style["color"] = "black";
	    document.getElementById('w'+t).style["backgroundColor"]= "#ffffff";
	    document.getElementById('w'+s).style["backgroundColor"]= "#ffffff";
        }

        function markCell(obj,s,t,l){
	    obj.style["border"] = "2pt solid #0000ff";
	    document.getElementById(t).style["color"] = "#ff0000";
	    document.getElementById(s).style["color"] = "#ff0000";
	    document.getElementById(l).style["color"] = "#ff0000";
	    document.getElementById('w'+t).style["color"] = "#ff0000";
	    document.getElementById('w'+s).style["color"] = "#ff0000";
        }

        function unmarkCell(obj,s,t,color,l){
	  //	    obj.style["border"] = "2pt solid " + color;
	    document.getElementById(t).style["color"] = "black";
	    document.getElementById(s).style["color"] = "black";
	    document.getElementById(l).style["color"] = "black";
	    document.getElementById('w'+t).style["color"] = "black";
	    document.getElementById('w'+s).style["color"] = "black";
        }

// ]]>
</script>
