#!/usr/bin/env python3
"""Test WebSocket Matchmaking WIWIGA"""

import asyncio
import websockets
import json

async def test_matchmaking():
    uri = "ws://localhost:8000/socket/websocket"
    
    print("=" * 50)
    print("  TEST WEBSOCKET MATCHMAKING")
    print("=" * 50)
    
    # Client 1
    print("\n1️⃣  Client 1 rejoint la file...")
    async with websockets.connect(uri) as ws1:
        # Join matchmaking room
        await ws1.send(json.dumps({
            "topic": "matchmaking:dice",
            "event": "phx_join",
            "payload": {},
            "ref": "1"
        }))
        
        response = await ws1.recv()
        data = json.loads(response)
        print(f"   ✅ Joined: {data['event']}")
        
        # Join queue
        await ws1.send(json.dumps({
            "topic": "matchmaking:dice",
            "event": "join_queue",
            "payload": {"bet_amount": 50000},
            "ref": "2"
        }))
        
        response = await ws1.recv()
        data = json.loads(response)
        print(f"   📊 Statut: {data['payload']['status']}")
        print(f"   📍 Position: {data['payload'].get('position', 'N/A')}")
        
        # Client 2
        print("\n2️⃣  Client 2 rejoint la file...")
        async with websockets.connect(uri) as ws2:
            await ws2.send(json.dumps({
                "topic": "matchmaking:dice",
                "event": "phx_join",
                "payload": {},
                "ref": "1"
            }))
            
            await ws2.recv()  # Join response
            
            await ws2.send(json.dumps({
                "topic": "matchmaking:dice",
                "event": "join_queue",
                "payload": {"bet_amount": 50000},
                "ref": "2"
            }))
            
            # Les deux devraient recevoir un match
            response1 = await asyncio.wait_for(ws1.recv(), timeout=5.0)
            data1 = json.loads(response1)
            print(f"   🎉 Client 1: {data1['event']}")
            
            response2 = await asyncio.wait_for(ws2.recv(), timeout=5.0)
            data2 = json.loads(response2)
            print(f"   🎉 Client 2: {data2['event']}")
            
            if data1['event'] == 'player_matched' and data2['event'] == 'player_matched':
                print("\n" + "=" * 50)
                print("  ✅ MATCHMAKING FONCTIONNEL !")
                print("=" * 50)
                print(f"  Game ID: {data1['payload']['game_id']}")
                print("=" * 50)

if __name__ == "__main__":
    try:
        asyncio.run(test_matchmaking())
    except Exception as e:
        print(f"\n❌ Erreur: {e}")
        print("Installez websockets: pip install websockets")
