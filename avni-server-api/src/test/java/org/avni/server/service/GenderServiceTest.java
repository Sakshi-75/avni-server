package org.avni.server.service;

import org.avni.server.dao.GenderRepository;
import org.joda.time.DateTime;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class GenderServiceTest {
    @Mock private GenderRepository genderRepository;
    private GenderService service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new GenderService(genderRepository);
    }
    
    @Test
    public void testIsNonScopeEntityChangedTrue() {
        DateTime dateTime = DateTime.now();
        when(genderRepository.existsByLastModifiedDateTimeGreaterThan(dateTime)).thenReturn(true);
        
        boolean result = service.isNonScopeEntityChanged(dateTime);
        
        assertTrue(result);
    }
    
    @Test
    public void testIsNonScopeEntityChangedFalse() {
        DateTime dateTime = DateTime.now();
        when(genderRepository.existsByLastModifiedDateTimeGreaterThan(dateTime)).thenReturn(false);
        
        boolean result = service.isNonScopeEntityChanged(dateTime);
        
        assertFalse(result);
    }
}
