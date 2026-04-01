//+------------------------------------------------------------------+
//| MagicNumber.mqh                                                   |
//| Encodes/decodes magic numbers for WakaGrid                        |
//| Format: direction * 10000000 + base_magic * 100 + level          |
//| Example: Buy L3 = 1*10000000 + 84570*100 + 3 = 18457003         |
//+------------------------------------------------------------------+
#ifndef MAGIC_NUMBER_MQH
#define MAGIC_NUMBER_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| CMagicNumber                                                      |
//+------------------------------------------------------------------+
class CMagicNumber
{
private:
   int m_base_magic;   // e.g., 84570

public:
   CMagicNumber() : m_base_magic(BASE_MAGIC_GRID) {}

   void Init(int base_magic)
   {
      m_base_magic = base_magic;
   }

   //+------------------------------------------------------------------+
   //| Encode magic number from direction + level                        |
   //+------------------------------------------------------------------+
   int Encode(int direction, int level)
   {
      // direction: DIR_BUY=1, DIR_SELL=2
      // level: 0-99
      return direction * 10000000 + m_base_magic * 100 + level;
   }

   //+------------------------------------------------------------------+
   //| Decode level from magic number                                    |
   //+------------------------------------------------------------------+
   static int DecodeLevel(int magic)
   {
      return magic % 100;
   }

   //+------------------------------------------------------------------+
   //| Decode direction from magic number                                |
   //+------------------------------------------------------------------+
   static int DecodeDirection(int magic)
   {
      return magic / 10000000;
   }

   //+------------------------------------------------------------------+
   //| Decode base magic from magic number                               |
   //+------------------------------------------------------------------+
   static int DecodeBase(int magic)
   {
      return (magic / 100) % 100000;
   }

   //+------------------------------------------------------------------+
   //| Check if a magic number belongs to this EA                        |
   //+------------------------------------------------------------------+
   bool BelongsToEA(int magic)
   {
      return (DecodeBase(magic) == m_base_magic);
   }

   //+------------------------------------------------------------------+
   //| Check if magic belongs to a specific direction                    |
   //+------------------------------------------------------------------+
   bool IsBuyMagic(int magic)
   {
      return BelongsToEA(magic) && (DecodeDirection(magic) == DIR_BUY);
   }

   bool IsSellMagic(int magic)
   {
      return BelongsToEA(magic) && (DecodeDirection(magic) == DIR_SELL);
   }

   int GetBaseMagic() { return m_base_magic; }
};

#endif
