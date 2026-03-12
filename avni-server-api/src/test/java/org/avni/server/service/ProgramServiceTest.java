package org.avni.server.service;

import org.avni.server.dao.OperationalProgramRepository;
import org.avni.server.dao.ProgramRepository;
import org.avni.server.dao.application.FormMappingRepository;
import org.avni.server.domain.Program;
import org.avni.server.web.request.ProgramRequest;
import org.joda.time.DateTime;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class ProgramServiceTest {
    @Mock private ProgramRepository programRepository;
    @Mock private OperationalProgramRepository operationalProgramRepository;
    @Mock private FormMappingRepository formMappingRepository;
    @Mock private RuleService ruleService;
    
    private ProgramService service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new ProgramService(programRepository, operationalProgramRepository, 
                                     formMappingRepository, ruleService);
    }
    
    @Test
    public void testSaveProgramNew() {
        ProgramRequest request = new ProgramRequest();
        request.setUuid("uuid1");
        request.setName("Test Program");
        request.setActive(true);
        request.setVoided(false);
        
        when(programRepository.findByUuid("uuid1")).thenReturn(null);
        when(programRepository.save(any(Program.class))).thenReturn(new Program());
        
        service.saveProgram(request);
        
        verify(programRepository, atLeast(1)).save(any(Program.class));
    }
    
    @Test
    public void testSaveProgramExisting() {
        ProgramRequest request = new ProgramRequest();
        request.setUuid("uuid1");
        request.setName("Updated Program");
        request.setVoided(false);
        
        Program existing = new Program();
        existing.setUuid("uuid1");
        when(programRepository.findByUuid("uuid1")).thenReturn(existing);
        when(programRepository.save(any(Program.class))).thenReturn(existing);
        
        service.saveProgram(request);
        
        verify(programRepository, atLeast(1)).save(existing);
    }
    
    @Test
    public void testUpdateAndSaveProgram() {
        Program program = new Program();
        ProgramRequest request = new ProgramRequest();
        request.setName("New Name");
        request.setColour("Red");
        request.setActive(true);
        request.setVoided(false);
        request.setAllowMultipleEnrolments(true);
        request.setManualEligibilityCheckRequired(false);
        request.setShowGrowthChart(true);
        
        when(programRepository.save(program)).thenReturn(program);
        
        Program result = service.updateAndSaveProgram(program, request);
        
        assertEquals("New Name", result.getName());
        assertEquals("Red", result.getColour());
        assertTrue(result.isAllowMultipleEnrolments());
        assertTrue(result.isShowGrowthChart());
        assertFalse(result.isManualEligibilityCheckRequired());
        verify(programRepository).save(program);
    }
    
    @Test
    public void testUpdateAndSaveProgramWithRules() {
        Program program = new Program();
        ProgramRequest request = new ProgramRequest();
        request.setName("Program With Rules");
        request.setEnrolmentSummaryRule("rule1");
        request.setEnrolmentEligibilityCheckRule("rule2");
        request.setManualEnrolmentEligibilityCheckRule("rule3");
        request.setVoided(false);
        
        when(programRepository.save(program)).thenReturn(program);
        
        Program result = service.updateAndSaveProgram(program, request);
        
        assertEquals("rule1", result.getEnrolmentSummaryRule());
        assertEquals("rule2", result.getEnrolmentEligibilityCheckRule());
        assertEquals("rule3", result.getManualEnrolmentEligibilityCheckRule());
    }
}
