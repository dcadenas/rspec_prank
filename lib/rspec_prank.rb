#!/usr/bin/ruby
require "inline"  
require "spec/runner/formatter/progress_bar_formatter"

module RspecPrank
  #Motion sensor code from FaziBear at http://fazibear.blogspot.com/2008/12/process-mac-sudden-motion-sensor-with.html
  class SMS  
    class << self  
      inline do |builder|  
        builder.add_compile_flags '-x objective-c', '-framework IOKit'  
        builder.include "<IOKit/IOKitLib.h>"      
        builder.c %q{  
        VALUE values(){  

          struct data {  
            unsigned short x;  
            unsigned short y;  
            unsigned short z;  
            char pad[34];  
          };  

          kern_return_t result;  

          mach_port_t masterPort;  
          IOMasterPort(MACH_PORT_NULL, &masterPort);  
          CFMutableDictionaryRef matchingDictionary = IOServiceMatching("SMCMotionSensor");  

          io_iterator_t iterator;  
          result = IOServiceGetMatchingServices(masterPort, matchingDictionary, &iterator);  

          if(result != KERN_SUCCESS) {  
            return rb_str_new2("Error");  
          }  

          io_object_t device = IOIteratorNext(iterator);  
          IOObjectRelease(iterator);  
          if(device == 0){  
            return rb_str_new2("Error");  
          }  

          io_connect_t dataPort;  
          result = IOServiceOpen(device, mach_task_self(), 0, &dataPort);  
          IOObjectRelease(device);  

          if(result != KERN_SUCCESS) {  
            return rb_str_new2("Error");  
          }  

          IOItemCount structureInputSize;  
          IOByteCount structureOutputSize;  

          struct data inputStructure;  
          struct data outputStructure;  
          structureInputSize = sizeof(struct data);  
          structureOutputSize = sizeof(struct data);  

          memset(&inputStructure, 1, sizeof(inputStructure));  
          memset(&outputStructure, 0, sizeof(outputStructure));  

          result = IOConnectMethodStructureIStructureO(  
            dataPort,  
            5,  
            structureInputSize,  
            &structureOutputSize,  
            &inputStructure,  
            &outputStructure  
          );  

          if(result != KERN_SUCCESS) {  
            return rb_str_new2("Error");  
          }  

          IOServiceClose(dataPort);  

          VALUE coords = rb_ary_new2(3);  
          rb_ary_store(coords, 0, INT2FIX(outputStructure.x));  
          rb_ary_store(coords, 1, INT2FIX(outputStructure.y));  
          rb_ary_store(coords, 2, INT2FIX(outputStructure.z));  

        return coords;  
        }  
        }  
      end  
    end  
  end  

  def self.fixnum_is_negative? s
    (s & 0x8000) != 0
  end

  def self.fixnum_to_negative s
    s - 0xFFFF
  end

  def self.to_tilt s
    signed = fixnum_is_negative?(s) ? fixnum_to_negative(s) : s
    signed += 0xFF
    signed < 0 ? 0 : signed
  end

  def self.tilt_handicap_seconds
    to_tilt(SMS.values.first) * 0.002
  end

  module ProgressBarFormatter
    module InstanceExtension
      %w[failed passed].each do |method|
        define_method "example_#{method}" do |*args|
          super *args
          sleep RspecPrank.tilt_handicap_seconds
        end
      end
    end

    module ClassExtension
      def new *args
        (super *args).extend RspecPrank::ProgressBarFormatter::InstanceExtension
      end
    end
  end
end

Spec::Runner::Formatter::ProgressBarFormatter.extend RspecPrank::ProgressBarFormatter::ClassExtension

