package org.avni.server.web.response;

import org.avni.server.domain.CHSBaseEntity;
import org.junit.Test;
import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class AvniEntityResponseTest {
    @Test
    public void testSuccessResponse() {
        CHSBaseEntity entity = mock(CHSBaseEntity.class);
        when(entity.getId()).thenReturn(123L);
        when(entity.getUuid()).thenReturn("test-uuid");
        
        AvniEntityResponse response = new AvniEntityResponse(entity);
        
        assertEquals(123L, response.getId());
        assertEquals("test-uuid", response.getUuid());
        assertTrue(response.isSuccess());
        assertNull(response.getErrorMessage());
    }
    
    @Test
    public void testErrorResponse() {
        AvniEntityResponse response = AvniEntityResponse.error("Test error");
        
        assertFalse(response.isSuccess());
        assertEquals("Test error", response.getErrorMessage());
    }
    
    @Test
    public void testSetters() {
        CHSBaseEntity entity = mock(CHSBaseEntity.class);
        when(entity.getId()).thenReturn(1L);
        when(entity.getUuid()).thenReturn("uuid1");
        
        AvniEntityResponse response = new AvniEntityResponse(entity);
        response.setId(456L);
        response.setUuid("new-uuid");
        
        assertEquals(456L, response.getId());
        assertEquals("new-uuid", response.getUuid());
    }
}
